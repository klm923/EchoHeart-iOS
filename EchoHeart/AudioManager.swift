import AVFoundation
import Accelerate
import Combine
import NotificationCenter
import MediaPlayer

class AudioManager: ObservableObject {
    static let shared = AudioManager()
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
                // オーディオエンジンを一度停止・リセットして、再起動する
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
    
    // audioEngineが動いているかどうかの新しいプロパティ
    var isAudioEngineRunning: Bool {
        return audioEngine.isRunning
    }
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.isEnabled = false
        commandCenter.playCommand.removeTarget(nil)
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if self.isRunning {
                self.stopMicrophone()
            }
            return .success
        }
        
        // その他必要なコマンドも追加
        commandCenter.togglePlayPauseCommand.isEnabled = false
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
    }
    
    func setupAudioSessionForAppLaunch(newListenMode: listenMode) {
        do {
            let session = AVAudioSession.sharedInstance()
            switch newListenMode {
            case .ambient:
//                try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothA2DP, .mixWithOthers, .defaultToSpeaker])
                // .mixWithOthersを入れるとロック画面に状況が表示されなくなる！！！
                try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothA2DP, .defaultToSpeaker])
                
                print("✅ 環境音モードに切り替えました")
                self.updateNowPlayingInfo(title: "Echo Heart", artist: "環境モードで動作中")
            case .conversation:
//                try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .mixWithOthers, .defaultToSpeaker])
                try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
                print("✅ 会話モードに切り替えました")
                self.updateNowPlayingInfo(title: "Echo Heart", artist: "会話モードで動作中")
            }
                //.defaultToSpeakerは、ヘッドホンが接続されてないときにiPhoneのスピーカーを使うオプション
            try session.setActive(true)
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

        
        setupEQ()
        // Now Playing コマンドセンターを設定
        setupRemoteCommandCenter()
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

        
        DispatchQueue.global(qos: .userInitiated).async {

            if !self.isHeadphonesConnected() {
                print("ヘッドホンを接続してください")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            // ✅ 再生開始前にオーディオセッションを再度アクティブにする！
//            do {
//                let session = AVAudioSession.sharedInstance()
//                try session.setActive(true)
//            } catch {
//                print("❌ AudioSessionアクティブ化エラー: \(error)")
//                completion(false)
//                return
//            }
//            self.setupAudioSessionForAppLaunch(newListenMode: self.selectedListenMode)

            print("startMicrophone - 0")
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
                    self.updateNowPlayingInfo(title: "Echo Heart", artist: self.selectedListenMode == .ambient ? "環境モードで動作中" : "会話モードで動作中")

                    print("MPNowPlayingInfoCenter設定完了")
                    
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
    
   
    func stopMicrophone() {
        if !isRunning { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        DispatchQueue.main.async {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil // ✅ 情報を削除
            print("🛑 Now Playing 情報を削除")
        }

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


extension AudioManager {
    func updateNowPlayingInfo(title: String,
                              artist: String = "Unknown Artist",) {

        var nowPlayingInfo = [String: Any]()

        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist

        if let image = UIImage(named: "NowPlayingArtwork") { // "AppIcon"はアタルのアプリのアイコン名に置き換えてね
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in
                return image
            }
        }

        // AVAudioPlayer 用に再生時間を設定
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: Float.greatestFiniteMagnitude)
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isRunning ? 1.0 : 0.0

        // メインスレッドで確実に更新する
        DispatchQueue.main.async {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
    }

}

