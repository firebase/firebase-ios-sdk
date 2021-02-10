//
//  FIAMSwiftUIApp.swift
//  Shared
//
//  Created by Chris Tibbs on 2/9/21.
//

import SwiftUI
import FirebaseInAppMessagingSwift

@main
struct FIAMSwiftUIApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView().modalInAppMessage { modalMessage, delegate in
        Text(modalMessage.title).padding()
      }
    }
  }
}
