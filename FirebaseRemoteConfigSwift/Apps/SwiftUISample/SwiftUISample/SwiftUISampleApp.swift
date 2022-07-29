//
//  SwiftUISampleApp.swift
//  SwiftUISample
//
//  Created by Charlotte Liang on 7/29/22.
//

import SwiftUI
import FirebaseCore

@main
struct SwiftUISampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
  init () {
    FirebaseApp.configure()
  }
}
