//
//  AppQualityDevAppApp.swift
//  Shared
//
//  Created by Sam Edson on 9/28/22.
//

import SwiftUI
import FirebaseCore
import FirebaseSessions

@main
struct AppQualityDevAppApp: App {
  init() {
    FirebaseApp.configure()
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//      fatalError()
    }
  }
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
