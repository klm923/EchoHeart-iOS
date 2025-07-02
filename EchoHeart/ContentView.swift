import SwiftUI
import AVFoundation
import AudioToolbox

func playClickSound(id: UInt32) {
    AudioServicesPlaySystemSound(id)
}

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var isMicOn = false

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

            VStack(spacing: 20) {
                Text("🎧EchoHeart🎧")
//                    .font(.largeTitle)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .bold()
                
                
                // 🎚 レベルメーター表示
                VStack(){
                    HStack(alignment: .bottom, spacing: 6) {
                        //                    Spacer()
                        ForEach(0..<audioManager.spectrumLevels.count, id: \.self) { i in
                            VStack{
                                Spacer()
                                Rectangle()
                                    .fill(Color(hue: (1.0 - Double(audioManager.spectrumLevels[i])) * 0.33, saturation: 1.0, brightness: 0.9).gradient)
                                    .cornerRadius(2)
                                .frame(width: 10, height: CGFloat(audioManager.spectrumLevels[i]) * 100)                        }
                        }
                        //                    Spacer()
                    }
                    .frame(height: 110)
                    //                Text("スペクトラム表示")
                }
                Spacer()
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Text("中心周波数: \(Int(audioManager.eqFrequency)) Hz")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                        Slider(value: $audioManager.eqFrequency, in: 1000...4000, step: 50)
                            .tint(Color.echoGreen)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 2, y: 2)
                    }
                    .padding(.horizontal, 20)
                    
                    VStack(alignment: .leading) {
                        Text("ゲイン: \(String(format: "%.1f", audioManager.eqGain)) dB")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                        Slider(value: $audioManager.eqGain, in: -20...60, step: 1.0)
                            .tint(Color.echoGreen)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 2, y: 2)
                    }
                    .padding(.horizontal, 20)
                    
                    VStack(alignment: .leading) {
                        Text("範囲: \(String(format: "%.1f", audioManager.eqWidth)) オクターブ")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                        Slider(value: $audioManager.eqWidth, in: 0.5...3.0, step: 0.1)
                            .tint(Color.echoGreen)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 2, y: 2)
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
                .padding()
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("🔊 全体音量: \(Int(audioManager.masterVolume * 10)) %")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                        Slider(value: $audioManager.masterVolume, in: 0...10.0, step: 0.1)
                            .tint(Color.echoGreen)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 2, y: 2)
                    }
                    .padding(.horizontal, 20)
                    Spacer()
                }
                .padding()
                
                Button(action: {
                    if isMicOn {
                        playClickSound(id: 1118) // 動画の録画停止音
                        audioManager.stopMicrophone()
                    } else {
                        playClickSound(id: 1117) // 動画の録画開始音
                        audioManager.startMicrophone()
                    }
                    isMicOn.toggle()
                }) {
                    Label(isMicOn ? "マイク オフ" : "マイク オン", systemImage: isMicOn ? "mic.slash.fill" : "mic.fill")
                        .font(.title)
                        .padding()
//                        .background(isMicOn ? Color.pink : Color.blue)
//                        .foregroundColor(.white)
//                        .cornerRadius(10)
                        .labelStyle(.iconOnly)
//                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.borderedProminent)
                .tint(isMicOn ? .echoPink : .echoBlue)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 2, y: 2)
                .padding()
                
            }
            //        .background(
            //            LinearGradient(gradient: Gradient(colors: [Color.white, Color.echoPink.opacity(0.2)]),
            //                           startPoint: .top,
            //                           endPoint: .bottom)
            //        )
        }
    }
}
