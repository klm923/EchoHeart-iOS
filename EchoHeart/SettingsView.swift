//
//  SettingsView.swift
//  EchoHeart
//
//  Created by klm923 on 2025/08/12.
//

import SwiftUI

struct SettingsView: View {
    // アプリのバージョン番号を取得
    let version: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
    
    // アプリのビルド番号を取得
    let build: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "N/A"

    var body: some View {
        List {
            Section(header: Text("バージョン情報").font(.system(size: 16, weight: .semibold, design: .rounded))) {
                HStack {
                    Text("バージョン").font(.system(size: 14, design: .rounded))
                    Spacer()
                    Text(version)
                        .foregroundColor(.gray)
                        .font(.system(size: 14, design: .rounded))
                }
                
                HStack {
                    Text("ビルド").font(.system(size: 14, design: .rounded))
                    Spacer()
                    Text(build)
                        .foregroundColor(.gray)
                        .font(.system(size: 14, design: .rounded))
                }
            }
            
            // ✅ ここに、今後追加したい設定項目を書いていくわ
            // 例：Toggle(isOn: .constant(true)) { Text("ハウリング防止") }
        }
        .navigationTitle("アプリの情報")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
        }
    }
}
