import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var isMicOn = false

    var body: some View {
        VStack(spacing: 20) {
            Text("🎧 EchoHeart")
                .font(.largeTitle)
                .bold()

            Button(action: {
                if isMicOn {
                    audioManager.stopMicrophone()
                } else {
                    audioManager.startMicrophone()
                }
                isMicOn.toggle()
            }) {
                Text(isMicOn ? "⛔️マイク　オフ" :"🎙️マイク　オン")
                    .font(.title2) // 👈 文字大きく
                    .padding()
                    .background(isMicOn ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            // 🎚 レベルメーター表示
            VStack(){
                HStack(alignment: .bottom, spacing: 6) {
//                    Spacer()
                    ForEach(0..<audioManager.spectrumLevels.count, id: \.self) { i in
                        VStack{
                            Spacer()
                            // アスカ様へ きれいなグラデーションにならない（レベルメータをが低いときも赤色になってしまう）
                            Rectangle()
                                .fill(Color(hue: Double(audioManager.spectrumLevels[i]), saturation: 1.0, brightness: 0.9))
                                .cornerRadius(2)
                                .frame(width: 10, height: CGFloat(audioManager.spectrumLevels[i]) * 100)
                        }
                    }
//                    Spacer()
                }
//                .frame(width: 100)
                .frame(height: 110)
//                Text("スペクトラム表示")
            }
            Spacer()
            
            VStack(spacing: 20) {
                // アスカ様へ　イコライザー設定は未実装
//                Text("🎚️ イコライザー設定")
                VStack(alignment: .leading) {
                    Text("🔊 全体音量: \(Int(audioManager.masterVolume * 10)) %")
                    Slider(value: $audioManager.masterVolume, in: 0...10.0, step: 0.1)
                }
                VStack(alignment: .leading) {
                    Text("中心周波数: \(Int(audioManager.eqFrequency)) Hz")
                    Slider(value: $audioManager.eqFrequency, in: 1000...4000, step: 50)
                }

                VStack(alignment: .leading) {
                    Text("ゲイン: \(String(format: "%.1f", audioManager.eqGain)) dB")
                    Slider(value: $audioManager.eqGain, in: -20...60, step: 1.0)
                }

                VStack(alignment: .leading) {
                    Text("範囲: \(String(format: "%.1f", audioManager.eqWidth)) オクターブ")
                    Slider(value: $audioManager.eqWidth, in: 0.5...3.0, step: 0.1)
                }

                Spacer()
            }
            .padding()

            
            
        }
        .padding()
    }
}
