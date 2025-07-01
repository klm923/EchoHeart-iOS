import AVFoundation
import Accelerate
import Combine

class AudioManager: ObservableObject {
    private var audioEngine = AVAudioEngine()
    private var eq = AVAudioUnitEQ(numberOfBands: 1)
    private var isRunning = false
    private var cancellables = Set<AnyCancellable>()
    private let barCount = 15
    private var inputFormat: AVAudioFormat?
    private let mainMixer: AVAudioMixerNode

    @Published var spectrumLevels: [Float]

    @Published var inputLevel: Float = 0.0  // 0〜1の範囲
    
    // 👇 ユーザーが調整する値
    @Published var eqFrequency: Float {
        didSet { UserDefaults.standard.set(eqFrequency, forKey: "eqFrequency") }
    }

    @Published var eqGain: Float {
        didSet { UserDefaults.standard.set(eqGain, forKey: "eqGain") }
    }

    @Published var eqWidth: Float {
        didSet { UserDefaults.standard.set(eqWidth, forKey: "eqWidth") }
    }

    @Published var masterVolume: Float {
        didSet {
            mainMixer.outputVolume = masterVolume
            UserDefaults.standard.set(masterVolume, forKey: "masterVolume")
        }
    }

    init() {
        self.spectrumLevels = Array(repeating: 0.0, count: barCount)
        self.mainMixer = audioEngine.mainMixerNode

        // デフォルト値をあらかじめ登録
        UserDefaults.standard.register(defaults: [
            "eqFrequency": 1000,
            "eqGain": 10,
            "eqWidth": 1.5,
            "masterVolume": 1.0
        ])

        // 登録されていればそれが使われる
        self.eqFrequency = UserDefaults.standard.float(forKey: "eqFrequency")
        self.eqGain = UserDefaults.standard.float(forKey: "eqGain")
        self.eqWidth = UserDefaults.standard.float(forKey: "eqWidth")
        self.masterVolume = UserDefaults.standard.float(forKey: "masterVolume")

        setupEQ()
    }

    private func setupEQ() {
        let band = eq.bands[0]
//        band.filterType = .parametric
        band.filterType = .bandPass
        band.bypass = false
        updateEQ()
    }

    private func updateEQ() {
        let band = eq.bands[0]
        band.gain = eqGain
        band.frequency = eqFrequency
        band.bandwidth = eqWidth
    }


    func startMicrophone() {
        if isRunning { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            print("❌ AudioSession設定エラー: \(error)")
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            self.processAudioBuffer(buffer: buffer)
        }

//        let mixer = audioEngine.mainMixerNode
        // アスカ様へ　増幅するのはここを設定するだけでＯＫ？
//        mixer.outputVolume = 1.5 // 0.0〜1.0 だが、Floatで1.5に設定してみる
        mainMixer.outputVolume = masterVolume
        
        let output = audioEngine.outputNode

        setupEQ()
        audioEngine.attach(eq)
        audioEngine.connect(inputNode, to: eq, format: format)
        audioEngine.connect(eq, to: mainMixer, format: format)
//        audioEngine.connect(mixer, to: output, format: format)
        audioEngine.connect(mainMixer, to: output, format: format)

        do {
            try audioEngine.start()
            isRunning = true
            print("🎙️ マイク＆音量監視開始")
        } catch {
            print("❌ AudioEngine起動エラー: \(error)")
        }
    }


    func processAudioBuffer(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        var window = [Float](repeating: 0, count: frameCount)
        var spectrum = [Float](repeating: 0.0, count: barCount)

        // Hannウィンドウで滑らかに
        vDSP_hann_window(&window, vDSP_Length(frameCount), Int32(vDSP_HANN_NORM))
        var samples = [Float](repeating: 0.0, count: frameCount)
        vDSP_vmul(channelData, 1, window, 1, &samples, 1, vDSP_Length(frameCount))

        // FFT用に複素数へ変換
        let log2n = UInt(round(log2(Float(frameCount))))
        let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        var realp = [Float](repeating: 0.0, count: frameCount / 2)
        var imagp = [Float](repeating: 0.0, count: frameCount / 2)

        realp.withUnsafeMutableBufferPointer { realPointer in
            imagp.withUnsafeMutableBufferPointer { imagPointer in
                var splitComplex = DSPSplitComplex(realp: realPointer.baseAddress!, imagp: imagPointer.baseAddress!)

                samples.withUnsafeMutableBufferPointer { ptr in
                    ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: frameCount) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(frameCount / 2))
                    }
                }

                // FFT実行
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

                // パワースペクトラムに変換
                var magnitudes = [Float](repeating: 0.0, count: frameCount / 2)
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(frameCount / 2))

                // ここでspectrum計算（バンド分け）
                let bandSize = magnitudes.count / barCount
                for i in 0..<barCount {
                    let start = i * bandSize
                    let end = start + bandSize
                    let slice = magnitudes[start..<min(end, magnitudes.count)]
                    let avg = sqrt(slice.reduce(0, +) / Float(slice.count))
                    spectrum[i] = min(max(avg * 3, 0), 1)
//                    print("Band \(i): avg = \(avg), scaled = \(avg * 3)")
                }

                DispatchQueue.main.async {
                    for i in 1..<self.barCount {
                        // 旧値に対して重みを加えて更新（α=0.2くらい）
                        let current = self.spectrumLevels[i]
                        self.spectrumLevels[i] = current * 0.8 + spectrum[i] * 0.2
                    }
                }
            }
        }


        vDSP_destroy_fftsetup(fftSetup)

    }
    
    func stopMicrophone() {
        if !isRunning { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioEngine.reset()
        for i in 1..<self.barCount {
            self.spectrumLevels[i] = 0
        }
        isRunning = false
        print("🛑 マイク停止")
    }
}
