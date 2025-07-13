import AVFoundation
import Accelerate
import Combine




class AudioManager: ObservableObject {
    private var audioEngine = AVAudioEngine()
    //    private var eqNode = AVAudioUnitEQ(numberOfBands: 1)
    // 修正後（バンド数を3つ指定する）
    private var eqNode = AVAudioUnitEQ(numberOfBands: 3)
    private var isRunning = false
    private var cancellables = Set<AnyCancellable>()
    private let barCount = 15
    private var inputFormat: AVAudioFormat?
    private let mainMixer: AVAudioMixerNode
    
    @Published var spectrumLevels: [Float]
    
    @Published var inputLevel: Float = 0.0  // 0〜1の範囲
    @Published var currentLevel: Float = 0.0
    private var levelTimer: Timer?
    private var isMonitoring = false
    
    // 👇 ユーザーが調整する値
    //    @Published var eqFrequency: Float {
    //        didSet { UserDefaults.standard.set(eqFrequency, forKey: "eqFrequency") }
    //    }
    //
    //    @Published var eqGain: Float {
    //        didSet { UserDefaults.standard.set(eqGain, forKey: "eqGain") }
    //    }
    //
    //    @Published var eqWidth: Float {
    //        didSet { UserDefaults.standard.set(eqWidth, forKey: "eqWidth") }
    //    }
    
    @Published var masterVolume: Float {
        didSet {
            mainMixer.outputVolume = masterVolume
            UserDefaults.standard.set(masterVolume, forKey: "masterVolume")
        }
    }
    
    @Published var lowGain: Float = 0.0 {
        didSet {
            eqNode.bands[0].gain = lowGain
            UserDefaults.standard.set(lowGain, forKey: "lowGain")
        }
    }
    @Published var midGain: Float = 0.0 {
        didSet {
            eqNode.bands[1].gain = midGain
            UserDefaults.standard.set(midGain, forKey: "midGain")
        }
    }
    @Published var highGain: Float = 0.0 {
        didSet {
            eqNode.bands[2].gain = highGain
            UserDefaults.standard.set(highGain, forKey: "highGain")
        }
    }
    
    init() {
        self.spectrumLevels = Array(repeating: 0.0, count: barCount)
        self.mainMixer = audioEngine.mainMixerNode
        
        // デフォルト値をあらかじめ登録
        UserDefaults.standard.register(defaults: [
            //            "eqFrequency": 1000,
            //            "eqGain": 10,
            //            "eqWidth": 1.5,
            "lowGain": 0.0,
            "midGain": 0.0,
            "highGain": 0.0,
            "masterVolume": 1.0
        ])
        
        // 登録されていればそれが使われる
        //        self.eqFrequency = UserDefaults.standard.float(forKey: "eqFrequency")
        //        self.eqGain = UserDefaults.standard.float(forKey: "eqGain")
        //        self.eqWidth = UserDefaults.standard.float(forKey: "eqWidth")
        self.lowGain = UserDefaults.standard.float(forKey: "lowGain")
        self.midGain = UserDefaults.standard.float(forKey: "midGain")
        self.highGain = UserDefaults.standard.float(forKey: "highGain")
        self.masterVolume = UserDefaults.standard.float(forKey: "masterVolume")
        
        setupEQ()
    }
    
    //    private func setupEQ() {
    //        let band = eq.bands[0]
    //        band.filterType = .parametric
    //        band.filterType = .bandPass
    //        band.bypass = false
    //        updateEQ()
    //    }
    
    //    private func updateEQ() {
    //        let band = eq.bands[0]
    //        band.gain = eqGain
    //        band.frequency = eqFrequency
    //        band.bandwidth = eqWidth
    //    }
    
    private func setupEQ() {
        eqNode.globalGain = 0 // 全体ゲイン
        
        // 低音
        let lowBand = eqNode.bands[0]
        lowBand.filterType = .parametric
        lowBand.frequency = 200.0
        lowBand.bandwidth = 1.0
        lowBand.gain = lowGain
        lowBand.bypass = false
        
        // 中音（既存の1kHz）
        let midBand = eqNode.bands[1]
        midBand.filterType = .parametric
        midBand.frequency = 1000.0
        midBand.bandwidth = 1.0
        midBand.gain = midGain
        midBand.bypass = false
        
        // 高音
        let highBand = eqNode.bands[2]
        highBand.filterType = .parametric
        highBand.frequency = 4000.0
        highBand.bandwidth = 1.0
        highBand.gain = highGain
        highBand.bypass = false
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
        
//        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
//            self.processAudioBuffer(buffer: buffer)
//        }
        
        mainMixer.outputVolume = masterVolume
        
        let output = audioEngine.outputNode
        
        setupEQ()
        audioEngine.attach(eqNode)
        audioEngine.connect(inputNode, to: eqNode, format: format)
        audioEngine.connect(eqNode, to: mainMixer, format: format)
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
//        for i in 1..<self.barCount {
//            self.spectrumLevels[i] = 0
//        }
        currentLevel = 0.0
        isRunning = false
        print("🛑 マイク停止")
    }
    
    func startMonitoringLevel() {
        // すでにtapが存在している場合は何もしない（2重tap防止）
        if isMonitoring { return }

        isMonitoring = true

        audioEngine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { buffer, _ in
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let channelDataValue = stride(from: 0,
                                          to: Int(buffer.frameLength),
                                          by: buffer.stride).map { channelData[$0] }

            let rms = sqrt(channelDataValue.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
            let avgPower = 20 * log10(rms)

            let meterLevel = self.normalizedPowerLevel(from: avgPower)
            DispatchQueue.main.async {
                self.currentLevel = meterLevel
            }
        }
    }

    func stopMonitoringLevel() {
        if isMonitoring {
            audioEngine.mainMixerNode.removeTap(onBus: 0)
            currentLevel = 0.0
            isMonitoring = false
        }
    }

    // 正規化（dBを0〜1に変換）
    private func normalizedPowerLevel(from decibels: Float) -> Float {
        let minDb: Float = -80
        if decibels < minDb {
            return 0.0
        } else if decibels >= 0 {
            return 1.0
        } else {
            return (decibels + abs(minDb)) / abs(minDb)
        }
    }
}
