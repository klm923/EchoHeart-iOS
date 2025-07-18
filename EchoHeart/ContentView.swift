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
    
    func handleAudioRouteChange(_ notification: Notification) {
        let session = AVAudioSession.sharedInstance()
        let route = session.currentRoute
        let hasHeadphones = route.outputs.contains { output in
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
                let vGapSlider = CGFloat(20)
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
                                .scaleEffect(0 + CGFloat(audioManager.currentLevel) * pinkCircleHeight)
                                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: audioManager.currentLevel)
                        }.frame(height: pinkCircleHeight)

                        ZStack() {
                            Image("AppLogo")  // ← 🎧の代わりにアイコン画像を表示
                                .resizable()
                                .frame(width: 128, height: 128)  // サイズはお好みで
                            //                        .clipShape(RoundedRectangle(cornerRadius: 12)) // オプション：角を丸めたいとき
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 2)
                                .blur(radius: 1) // 👈 半径2ポイント分ぼかし
                            //                        .blur(radius: audioManager.currentLevel > 0.1 ? 1 : 0)
                            //                        .animation(.easeInOut(duration: 0.2), value: audioManager.currentLevel)
                            VStack() {
                                Spacer().frame(height: 128)
                                HStack {
                                    Image(systemName: "speaker.wave.3.fill")
                                    Text("\(Int(systemVolume * 100))%")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                 }
                                .foregroundColor(.secondary)
                            }
//                            .font(.subheadline)
//                            Spacer()
                        }

                        
                    }
                    
    //                Spacer().frame(height: 10)
                    
                                    
    //                Spacer()
                    
                    
                    VStack() {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("低音 (200Hz): \(Int(audioManager.lowGain)) dB")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                            FatSlider(value: $audioManager.lowGain, range: -24...24)
                        }.padding(.horizontal, 20)
//                        Spacer()
                        Spacer().frame(height: vGapSlider)

                        VStack(alignment: .leading, spacing: 0) {
                            Text("中音 (1000Hz): \(Int(audioManager.midGain)) dB")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                            FatSlider(value: $audioManager.midGain, range: -24...24)
                        }.padding(.horizontal, 20)
//                        Spacer()
                        Spacer().frame(height: vGapSlider)

                        VStack(alignment: .leading, spacing: 0) {
                            Text("高音 (4000Hz): \(Int(audioManager.highGain)) dB")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                            FatSlider(value: $audioManager.highGain, range: -24...24)
                        }.padding(.horizontal, 20)
                    }
                    .padding()
                    Spacer(minLength: 0)
                    
                    VStack() {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 0) {
                                Image(systemName: "waveform")
                                Text("増幅率: \(Int(audioManager.masterVolume * 10)) %")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                            }
                            FatSlider(value: $audioManager.masterVolume, range: 0...10.0)
                            
                        }
                        .padding(.horizontal, 20)
    //                    Spacer()
                    }
                    .padding()
                    
                    Spacer()
                    
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
                            
//                            if audioManager.startMicrophone() {
//                                playClickSound(id: 1117) // 動画の録画開始音
//                                isMicOn.toggle()
//                            } else {
//                                showNoHeadphonesAlert = true
//                            }
                        }
                        
                    }) {
                        Label(isMicOn ? "マイク オフ" : "マイク オン", systemImage: isMicOn ? "mic.slash.fill" : "mic.fill")
                            .font(.title)
                            .padding()
                            .labelStyle(.iconOnly)
//                            .frame(width: 128, height: 128)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isMicOn ? .echoPink : .echoBlue)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 2)
                    .padding()
                    .alert("⚠️ ヘッドホン未接続", isPresented: $showNoHeadphonesAlert) {
                    } message: {
                        Text("録音するにはヘッドホンを接続してください")
                    }
                    Spacer()
                }
//                .onAppear {
//                    print("geometry.size.height: \(geometry.size.height)")
//                }
            }
        }
        .onAppear {
//                    audioManager.startAudio() // あれば
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
