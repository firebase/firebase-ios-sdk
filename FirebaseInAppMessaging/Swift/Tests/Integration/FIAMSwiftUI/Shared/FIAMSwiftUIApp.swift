//
//  FIAMSwiftUIApp.swift
//  Shared
//
//  Created by Chris Tibbs on 2/9/21.
//

import SwiftUI

import FirebaseCore
import FirebaseInAppMessagingSwift

@main
struct FIAMSwiftUIApp: App {
  init() {
    FirebaseApp.configure()
  }

  var body: some Scene {
    WindowGroup {
      ContentView().modalInAppMessage { modalMessage, delegate in
        Text(modalMessage.title).padding()
      }
    }
  }
}
