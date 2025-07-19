import AVFoundation
import Accelerate
import Combine
import NotificationCenter




class AudioManager: ObservableObject {
    private var audioEngine = AVAudioEngine()
    //    private var eqNode = AVAudioUnitEQ(numberOfBands: 1)
    // 修正後（バンド数を3つ指定する）
    private var eqNode = AVAudioUnitEQ(numberOfBands: 3)
    private var isRunning = false
//    private var isStarting = true
    private var cancellables = Set<AnyCancellable>()
    private let barCount = 15
    private var inputFormat: AVAudioFormat?
    private let mainMixer: AVAudioMixerNode
    
    @Published var spectrumLevels: [Float]
    
    @Published var inputLevel: Float = 0.0  // 0〜1の範囲
    @Published var currentLevel: Float = 0.0
    private var levelTimer: Timer?
    private var isMonitoring = false
    private var _currentRawLevel: Float = 0.0 // ここに生のレベルを一時保存
    private var levelUpdateTimer: Timer? // タイマーを保持するプロパティ
    
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
    @Published var selectedListenMode: listenMode = .ambient { // 変数名をlistenModeからselectedListenModeに変えてみたよ、区別しやすくなるからね
        didSet {
            // モードを切り替える
            setupAudioSessionForAppLaunch(newListenMode: selectedListenMode)
            if isRunning { // 録音中なら…
                // オーディオエンジンを一度停止・リセットして、再起動する処理もここに入れるといいかも
                self.audioEngine.stop()
                self.audioEngine.reset()
                isRunning = false
                self.startMicrophone { success in
                    if success {
                        self.isRunning = true
                    } else {
                        self.stopMicrophone()
                    }
                }
            }
            // listenModeのRaw Value（文字列）を保存する
            UserDefaults.standard.set(selectedListenMode.rawValue, forKey: "listenMode")
        }
    }
    func setupAudioSessionForAppLaunch(newListenMode: listenMode) {
        do {
            let session = AVAudioSession.sharedInstance()
            switch newListenMode {
            case .ambient:
                try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothA2DP, ])
                print("✅ 環境音モードに切り替えました")
            case .conversation:
                try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, ])
                print("✅ 会話モードに切り替えました")
            }
                //.defaultToSpeakerは、ヘッドホンが接続されてないときにiPhoneのスピーカーを使うオプション
            try session.setActive(true, options: .notifyOthersOnDeactivation) // ここで非同期で完了を待つオプションも検討
            print("✅ アプリ起動時AudioSession設定完了")
        } catch {
            print("❌ アプリ起動時AudioSession設定エラー: \(error)")
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
            "masterVolume": 1.0,
            "listenMode": "ambient"
        ])
        
        self.lowGain = UserDefaults.standard.float(forKey: "lowGain")
        self.midGain = UserDefaults.standard.float(forKey: "midGain")
        self.highGain = UserDefaults.standard.float(forKey: "highGain")
        self.masterVolume = UserDefaults.standard.float(forKey: "masterVolume")
        if let savedModeString = UserDefaults.standard.string(forKey: "listenMode") {
            // 読み出した文字列から listenMode を初期化する
            // Raw Valueからenumを初期化するfailable initializerを使う
            self.selectedListenMode = listenMode(rawValue: savedModeString)  ?? .ambient //でデフォルト値を指定
        } else {
            // 保存されたデータがない場合はデフォルト値を使う
            self.selectedListenMode = .ambient
        }

        
        setupAudioSessionForAppLaunch(newListenMode: self.selectedListenMode)
        setupEQ()
    }
    
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
    
    
    func isHeadphonesConnected() -> Bool {
        let route = AVAudioSession.sharedInstance().currentRoute
        for output in route.outputs {
            if output.portType == .headphones || output.portType == .bluetoothA2DP || output.portType == .bluetoothLE || output.portType == .bluetoothHFP {
                return true
            }
        }
        return false
    }
    
    func startMicrophone(completion: @escaping (Bool) -> Void) {
        if isRunning {
            completion(true)
            return
        }

//        setupAudioSessionForAppLaunch()
        
        DispatchQueue.global(qos: .userInitiated).async {

            if !self.isHeadphonesConnected() {
                print("ヘッドホンを接続してください")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            let inputNode = self.audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            let output = self.audioEngine.outputNode

            self.mainMixer.outputVolume = self.masterVolume
            self.setupEQ()
            self.audioEngine.attach(self.eqNode)
            self.audioEngine.connect(inputNode, to: self.eqNode, format: format)
            self.audioEngine.connect(self.eqNode, to: self.mainMixer, format: format)
            self.audioEngine.connect(self.mainMixer, to: output, format: format)

            self.audioEngine.prepare()
//            Thread.sleep(forTimeInterval: 0.1) // ←これを入れないと初回録音スタート（audioEngine.start()）で空振りする

            do {
                try self.audioEngine.start()
                DispatchQueue.main.async {
                    self.isRunning = true
                    print("🎙️ マイク＆音量監視開始")
                    completion(true)
                }
            } catch {
                print("❌ AudioEngine起動エラー: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    
//    func processAudioBuffer(buffer: AVAudioPCMBuffer) {
//        guard let channelData = buffer.floatChannelData?[0] else { return }
//        let frameCount = Int(buffer.frameLength)
//        var window = [Float](repeating: 0, count: frameCount)
//        var spectrum = [Float](repeating: 0.0, count: barCount)
//        
//        // Hannウィンドウで滑らかに
//        vDSP_hann_window(&window, vDSP_Length(frameCount), Int32(vDSP_HANN_NORM))
//        var samples = [Float](repeating: 0.0, count: frameCount)
//        vDSP_vmul(channelData, 1, window, 1, &samples, 1, vDSP_Length(frameCount))
//        
//        // FFT用に複素数へ変換
//        let log2n = UInt(round(log2(Float(frameCount))))
//        let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
//        var realp = [Float](repeating: 0.0, count: frameCount / 2)
//        var imagp = [Float](repeating: 0.0, count: frameCount / 2)
//        
//        realp.withUnsafeMutableBufferPointer { realPointer in
//            imagp.withUnsafeMutableBufferPointer { imagPointer in
//                var splitComplex = DSPSplitComplex(realp: realPointer.baseAddress!, imagp: imagPointer.baseAddress!)
//                
//                samples.withUnsafeMutableBufferPointer { ptr in
//                    ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: frameCount) { complexPtr in
//                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(frameCount / 2))
//                    }
//                }
//                
//                // FFT実行
//                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
//                
//                // パワースペクトラムに変換
//                var magnitudes = [Float](repeating: 0.0, count: frameCount / 2)
//                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(frameCount / 2))
//                
//                // ここでspectrum計算（バンド分け）
//                let bandSize = magnitudes.count / barCount
//                for i in 0..<barCount {
//                    let start = i * bandSize
//                    let end = start + bandSize
//                    let slice = magnitudes[start..<min(end, magnitudes.count)]
//                    let avg = sqrt(slice.reduce(0, +) / Float(slice.count))
//                    spectrum[i] = min(max(avg * 3, 0), 1)
//                    //                    print("Band \(i): avg = \(avg), scaled = \(avg * 3)")
//                }
//                
//                DispatchQueue.main.async {
//                    for i in 1..<self.barCount {
//                        // 旧値に対して重みを加えて更新（α=0.2くらい）
//                        let current = self.spectrumLevels[i]
//                        self.spectrumLevels[i] = current * 0.8 + spectrum[i] * 0.2
//                    }
//                }
//            }
//        }
//        
//        
//        vDSP_destroy_fftsetup(fftSetup)
//        
//    }
    
    func stopMicrophone() {
        if !isRunning { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioEngine.reset()
        currentLevel = 0.0
        isRunning = false
        print("🛑 マイク停止")
    }
    
    func startMonitoringLevel() {
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
            
            // UI更新はせずに、生のレベルだけを一時保存
            self._currentRawLevel = meterLevel
        }
        
        // タイマーを開始して、UIを定期的に更新する
        // 例: 1秒間に30回（1.0 / 30.0 = 約0.033秒ごと）更新
        levelUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // メインスレッドでUIを更新
            DispatchQueue.main.async {
                if self.isRunning {
                    self.currentLevel = self._currentRawLevel
                }
            }
        }
    }
    
    func stopMonitoringLevel() {
        if isMonitoring {
            audioEngine.mainMixerNode.removeTap(onBus: 0)
            currentLevel = 0.0
            isMonitoring = false
            // タイマーを停止するのも忘れずに！
            levelUpdateTimer?.invalidate()
            levelUpdateTimer = nil
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
