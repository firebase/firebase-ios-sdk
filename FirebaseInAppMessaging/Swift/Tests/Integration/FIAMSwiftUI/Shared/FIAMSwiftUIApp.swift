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
        VStack {
          if let imageData = modalMessage.imageData?.imageRawData,
            let image = UIImage(data: imageData) {
            Image(uiImage: image)
          }
          Text(modalMessage.title).padding(4)
          if let bodyText = modalMessage.bodyText {
            Text(bodyText).padding(4)
          }
        }
        .background(Color.white)
        .border(Color.black)
        .cornerRadius(4)
        .onAppear {
          delegate.impressionDetected?(for: modalMessage)
        }
      }
    }
  }

  func optionalButton(buttonInfo: (String, () -> Void)?) -> AnyView {
    if let buttonInfo = buttonInfo {
      return AnyView(Button(action: {
        buttonInfo.1()
      }) {
        Text(buttonInfo.0)
      })
    }
    return AnyView(EmptyView())
  }
}
