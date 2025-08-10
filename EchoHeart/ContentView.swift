import SwiftUI
import AVFoundation
import AudioToolbox
import MediaPlayer

func playClickSound(id: UInt32) {
    AudioServicesPlaySystemSound(id)
}



struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var isMicOn = false
    @State private var showNoHeadphonesAlert = false
    @State private var systemVolume: Float = AVAudioSession.sharedInstance().outputVolume
    private let volumeCheckTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    @State private var hasHeadphones = false
//    @State private var selectedMode: listenMode = .ambient
//    @State private var isUpsideDown: Bool = true {
//        didSet {
//            // isUpsideDown の値が変わったら向きを更新
//            updateOrientation()
//        }
//    }
//    
//    private func updateOrientation() {
//        let newOrientationMask: UIInterfaceOrientationMask // AppOrientationManagerに渡す用
//        let preferredInterfaceOrientation: UIInterfaceOrientation // UIDevice.current.setValueに渡す用
//
//        if isUpsideDown {
//            newOrientationMask = .portraitUpsideDown
//            preferredInterfaceOrientation = .portraitUpsideDown // ここを .portraitUpsideDown にするよ！
//        } else {
//            newOrientationMask = .portrait
//            preferredInterfaceOrientation = .portrait
//        }
//
//        // 1. AppOrientationManager の許可する向きを更新
//        AppOrientationManager.orientationLock = newOrientationMask
//
//        // 2. UIWindowScene を使って向きをリクエスト（iOS 16.0以降で推奨）
//        // これが新しいiOSで重要！
//        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
//            if #available(iOS 16.0, *) {
//                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: newOrientationMask))
//            } else {
//                // Fallback on earlier versions
//            }
//        }
//
//        // 3. 古いAPIも使って強制的に向きをトリガー（iOS 15以前のフォールバック & iOS 16+でも強力なヒントとして）
//        // これが、トグルで戻らない問題や、iOS 18でportraitUpsideDownが動かない問題の解決に役立つ可能性があるよ
//        UIDevice.current.setValue(preferredInterfaceOrientation.rawValue, forKey: "orientation")
//        UIViewController.attemptRotationToDeviceOrientation()
//    }

    func handleAudioRouteChange(_ notification: Notification) {
        let session = AVAudioSession.sharedInstance()
        let route = session.currentRoute
        hasHeadphones = route.outputs.contains { output in
            output.portType == .headphones ||
            output.portType == .bluetoothA2DP ||
            output.portType == .bluetoothHFP ||
            output.portType == .bluetoothLE
        }
        
        // 録音中にヘッドホンの接続が切れたら、録音を停止する
        if !hasHeadphones && isMicOn {
            audioManager.stopMicrophone()
            showNoHeadphonesAlert = true
            isMicOn = false
        }
        
        print("🔁 オーディオルート変更！ヘッドホン接続状態: \(hasHeadphones)")
        // → UI更新が必要なら @State を使って反映
    }

    var body: some View {
        ZStack {
            // グラデーション背景（SafeAreaもカバー）
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.echoPink.opacity(0.2),
                    Color.white
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            GeometryReader { geometry in
                let vGapSlider = geometry.size.height > 700 ? CGFloat(20) : CGFloat(10)
                let pinkCircleHeight = CGFloat(geometry.size.height / 4)
                VStack() {
                    Text("EchoHeart")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .bold()
                    
                    ZStack {
                        VStack() {
                            // 🟣 ぽよんぽよんするピンクの◯
                            Circle()
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(colors: [.pink.opacity(0.8), .pink.opacity(0.0)]),
                                        center: .center,
                                        startRadius: 0.1,
                                        endRadius: 1.0
                                    )
                                )
                                .blur(radius: CGFloat(audioManager.currentLevel * 0.05))
                                .frame(width: 1, height: 1)
                                .scaleEffect(CGFloat(audioManager.currentLevel) * pinkCircleHeight)
                                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: audioManager.currentLevel)
                        }.frame(height: pinkCircleHeight)

                        VStack(spacing:0) {
                            Image("AppLogo")  // ← 🎧の代わりにアイコン画像を表示
                                .resizable()
                                .frame(width: 128, height: 128)  // サイズはお好みで
                            //                        .clipShape(RoundedRectangle(cornerRadius: 12)) // オプション：角を丸めたいとき
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 2)
                                .blur(radius: 1) // 👈 半径2ポイント分ぼかし
                            //                        .blur(radius: audioManager.currentLevel > 0.1 ? 1 : 0)
                            //                        .animation(.easeInOut(duration: 0.2), value: audioManager.currentLevel)
                        }.frame(height: pinkCircleHeight)

                        VStack(spacing:0) {
                            Spacer() //.frame(height: 128)
                            HStack {
                                Image(systemName: "speaker.wave.3.fill")
                                Text("\(Int(systemVolume * 100))%")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                             }
                            .foregroundColor(.secondary)
                            Text(hasHeadphones ? "" : "ヘッドホン未接続")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(hasHeadphones ? .secondary : .red)
                            Spacer().frame(height: vGapSlider)
                        }.frame(height: pinkCircleHeight)
                        
                    }
                    
                    Divider()
                    
                    VStack() {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("高音 (4000Hz): \(Int(audioManager.highGain)) dB")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                            FatSlider(value: $audioManager.highGain, range: -24...24)
                        }.padding(.horizontal, 20)
                        Spacer().frame(height: vGapSlider)

                        VStack(alignment: .leading, spacing: 0) {
                            Text("中音 (1000Hz): \(Int(audioManager.midGain)) dB")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                            FatSlider(value: $audioManager.midGain, range: -24...24)
                        }.padding(.horizontal, 20)
                        Spacer().frame(height: vGapSlider)
                        
                        VStack(alignment: .leading, spacing: 0) {
                            Text("低音 (200Hz): \(Int(audioManager.lowGain)) dB")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                            FatSlider(value: $audioManager.lowGain, range: -24...24)
                        }.padding(.horizontal, 20)
                        Spacer().frame(height: vGapSlider)

                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 0) {
                                Image(systemName: "waveform")
                                Text("増幅率: \(Int(audioManager.masterVolume * 10)) %")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                            FatSlider(value: $audioManager.masterVolume, range: 0...10.0)
                        }.padding(.horizontal, 20)
                        Spacer().frame(height: vGapSlider)
                        
                        Picker("モード", selection: $audioManager.selectedListenMode) {
                            Text("環境音モード").tag(listenMode.ambient)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                            Text("会話モード").tag(listenMode.conversation)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .pickerStyle(.segmented) // これでセグメンテッドコントロールになるよ
                        .padding(.horizontal, 20)
//                        .onChange(of: selectedMode) { oldValue, newValue in
//                                    // selectedMode が変更された時に、この中のコードが実行されるよ
//                                    print("モードが \(oldValue) から \(newValue) に変わったよ！")
//                                    
//                                    // ここでオーディオセッションのオプションを切り替える関数を呼ぶ
//                                    // 例えば、handleModeChange(newMode: newValue) とか
//                                    handleModeChange(newMode: newValue)
                    }
                    .padding(.all, vGapSlider)
                    
                    Spacer()
                    
                    VStack() {

                        Button(action: {
                            if isMicOn {
                                audioManager.stopMicrophone()
                                playClickSound(id: 1118) // 動画の録画停止音
                                isMicOn.toggle()
                            } else {
                                audioManager.startMicrophone { success in
                                    if success {
                                        // マイクが正常に開始された → UI更新
                                        playClickSound(id: 1117) // 動画の録画開始音
                                        self.isMicOn = true
                                    } else {
                                        // エラー時のUI通知や処理
                                        self.isMicOn = false
                                        showNoHeadphonesAlert = true
                                        print("⚠️ マイク起動に失敗しました")
                                    }
                                }
                            }
                            
                        }) {
                            Image(systemName: isMicOn ? "mic.slash.fill" : "mic.fill")
    //                                                .padding()
    //                                                .resizable()
                                                    .frame(width: 50, height: 50)
                                                    .imageScale(.large)
                                                    .foregroundColor(hasHeadphones ? Color.white : Color.gray.opacity(0.5))
                                                    .background(hasHeadphones ? (isMicOn ? Color.echoPink : Color.echoBlue) : Color.gray.opacity(0.3))
                                                    .clipShape(Circle())
                                                    .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 2)
                                                    .scaleEffect(2.0)
    //                        Label(isMicOn ? "マイク オフ" : "マイク オン", systemImage: isMicOn ? "mic.slash.fill" : "mic.fill")
    //                            .font(.title)
    //                            .padding()
    //                            .labelStyle(.iconOnly)
    //                            .frame(width: 128, height: 128)
                        }
    //                    .buttonStyle(.borderedProminent)
    //                    .tint(isMicOn ? .echoPink : .echoBlue)
    //                    .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 2)
    //                    .padding(.all, 50)
                        .disabled(!hasHeadphones)
                        .alert("⚠️ ヘッドホン未接続", isPresented: $showNoHeadphonesAlert) {
                        } message: {
                            Text("録音するにはヘッドホンを接続してください")
                        }
                        
                    }
                    
                    Spacer()
                }
//                .onAppear {
//                    print("geometry.size.height: \(geometry.size.height)")
//                }
            }
        }
        .onAppear {
            // Viewが表示されたときに初期状態の向きを設定
            // ユーザーが前回どちらを選んだか UserDefaults で読み出して設定してもいいかもね
//            updateOrientation()
            
            audioManager.startMonitoringLevel()
            NotificationCenter.default.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: .main
            ) { notification in
                handleAudioRouteChange(notification)
            }

        }
        .onDisappear {
            audioManager.stopMonitoringLevel()
            NotificationCenter.default.removeObserver(self,
                name: AVAudioSession.routeChangeNotification,
                object: nil)
            // Viewが非表示になったら、向きの制限を解除する（念のため）
//            AppOrientationManager.orientationLock = .all
//            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
//                if #available(iOS 16.0, *) {
//                    windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .all))
//                } else {
//                    // Fallback on earlier versions
//                }
//            }
//            UIDevice.current.setValue(UIInterfaceOrientation.unknown.rawValue, forKey: "orientation")
//            UIViewController.attemptRotationToDeviceOrientation()
        }
        .onReceive(volumeCheckTimer) { _ in
            let current = AVAudioSession.sharedInstance().outputVolume
            if abs(current - systemVolume) > 0.01 {
                systemVolume = current
                print("音量変更検知: \(current)")
            }
        }
    }
}
