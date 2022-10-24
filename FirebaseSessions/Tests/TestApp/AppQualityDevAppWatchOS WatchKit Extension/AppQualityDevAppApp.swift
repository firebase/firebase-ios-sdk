//
//  AppQualityDevAppApp.swift
//  AppQualityDevAppWatchOS WatchKit Extension
//
//  Created by Leo Zhan on 2022-10-19.
//

import SwiftUI
import FirebaseCore

@main
struct AppQualityDevAppApp: App {
    init() {
      FirebaseApp.configure()
      DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
  //      fatalError()
      }
    }
  
    @SceneBuilder var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
            }
        }

        WKNotificationScene(controller: NotificationController.self, category: "myCategory")
    }
}
