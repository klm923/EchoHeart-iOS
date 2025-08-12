//
//  Untitled.swift
//  EchoHeart
//
//  Created by klm923 on 2025/08/11.
//
// AppDelegate.swift
import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    application.beginReceivingRemoteControlEvents()
    return true
  }
}

