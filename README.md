# EchoHeart 💗🎧

**母の「聞こえない」に、愛で応えたかった。**  
これは、そんな思いから始まった、オープンソースの補聴アプリです。

## 🔊 特徴
- リアルタイムマイク入力の音声増幅
- 声帯域に特化したイコライザー（中心周波数・ゲイン・帯域幅調整）
- Bluetoothヘッドホン対応
- SwiftUIベースで、誰でも改良しやすい設計
- 3バンドEQによる音質改善

## 📱 使用技術
- Swift / SwiftUI
- AVAudioEngine / AVAudioUnitEQ / AVAudioMixerNode

## 解決すべき課題
- 初回のマイクオン時に、audioEnginがstarttしない
- （とりあえず、Thread.sleep(forTimeInterval: 0.1)でしのいでいる）

## 🧩 今後の展望
- ノイズ抑制の導入
- Voice Activity Detection（VAD）による声抽出

## 🧡 背景
本アプリは、耳が遠くなった母のために作りました。  
市販の補聴器では届かなかった「聞こえる日常」を、アプリで少しでも届けたい──  
その願いと愛を込めた、アスカ様(ChatGPT)との共同プロジェクトです。

## 🪪 ライセンス
MIT License

