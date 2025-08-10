//
//  EchoHeartApp.swift
//  EchoHeart
//
//  Created by klm923 on 2025/06/19.
//

import SwiftUI

@main
struct EchoHeartApp: App {
    
//    @UIApplicationDelegateAdaptor(AppOrientationManager.self) var appDelegateManager
    
    
    var body: some Scene {
        WindowGroup {
            ContentView()
            // ここで設定したいViewにモディファイアを適用する
                            // 例えば、 ContentView の表示中は逆さま（Upside Down）を許可したい場合
                            // .enableSpecificOrientation(.portraitUpsideDown)

                            // ユーザーが切り替えたい場合は、ContentView内で isUpsideDown のStateに連動させる
                            // ここでは特に設定せず、ContentViewの中で制御する
        }
    }
}
