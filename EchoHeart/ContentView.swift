import SwiftUI
import AVFoundation
import AudioToolbox

func playClickSound(id: UInt32) {
    AudioServicesPlaySystemSound(id)
}

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var isMicOn = false
    @State private var showNoHeadphonesAlert = false

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

            VStack(spacing: 0) {
                Image("AppLogo")  // ← 🎧の代わりにアイコン画像を表示
                    .resizable()
                    .frame(width: 76, height: 76)  // サイズはお好みで
                    .clipShape(RoundedRectangle(cornerRadius: 12)) // オプション：角を丸めたいとき
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 2, y: 2)
                Spacer().frame(height: 10)
                Text("EchoHeart")
                //                    .font(.largeTitle)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .bold()
                
                                
                VStack() {
//                    Spacer()
                    
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
//                        .opacity(Double(audioManager.currentLevel))
                        .blur(radius: CGFloat(audioManager.currentLevel * 0.1))
                        .frame(width: 1, height: 1)
                        .scaleEffect(0 + CGFloat(audioManager.currentLevel) * 200)
                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: audioManager.currentLevel)
                    
//                    Spacer()
                    
                    // 他のUI（スライダーとか）
                }.frame(height: 200)
//                Spacer()
                
                
                VStack(spacing: 0) {
                    VStack(alignment: .leading) {
                        Text("低音 (200Hz): \(Int(audioManager.lowGain)) dB")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        FatSlider(value: $audioManager.lowGain, range: -24...24)
                    }.padding(.horizontal, 20)
                    Spacer().frame(height: 20)

                    VStack(alignment: .leading) {
                        Text("中音 (1000Hz): \(Int(audioManager.midGain)) dB")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        FatSlider(value: $audioManager.midGain, range: -24...24)
                    }.padding(.horizontal, 20)
                    Spacer().frame(height: 20)

                    VStack(alignment: .leading) {
                        Text("高音 (4000Hz): \(Int(audioManager.highGain)) dB")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        FatSlider(value: $audioManager.highGain, range: -24...24)
                    }.padding(.horizontal, 20)
                }
                .padding()
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("🔊 全体音量: \(Int(audioManager.masterVolume * 10)) %")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                        FatSlider(value: $audioManager.masterVolume, range: 0...10.0)
                        
                    }
                    .padding(.horizontal, 20)
//                    Spacer()
                }
                .padding()
                
                Button(action: {
                    if isMicOn {
                        audioManager.stopMicrophone()
                        playClickSound(id: 1118) // 動画の録画停止音
                        isMicOn.toggle()
                    } else {
                        if audioManager.startMicrophone() {
                            playClickSound(id: 1117) // 動画の録画開始音
                            isMicOn.toggle()
                        } else {
                            showNoHeadphonesAlert = true
                        }
                    }
                    
                }) {
                    Label(isMicOn ? "マイク オフ" : "マイク オン", systemImage: isMicOn ? "mic.slash.fill" : "mic.fill")
                        .font(.title)
                        .padding()
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderedProminent)
                .tint(isMicOn ? .echoPink : .echoBlue)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 2)
                .padding()
                .alert("⚠️ ヘッドホン未接続", isPresented: $showNoHeadphonesAlert) {
                } message: {
                    Text("録音するにはヘッドホンを接続してください")
                }
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

    }
}
