//
//  FIAMSwiftUIApp.swift
//  Shared
//
//  Created by Chris Tibbs on 2/9/21.
//

import SwiftUI

import FirebaseCore
import FirebaseInAppMessaging
import FirebaseInAppMessagingSwift

@main
struct FIAMSwiftUIApp: App {
  init() {
    FirebaseApp.configure()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .modalInAppMessage { modalMessage, delegate in
          ModalInAppMessageView(modalMessage: modalMessage, delegate: delegate)
        }
    }
  }

  // This can be in another file, for cleaner organization.
  struct ModalInAppMessageView: View {
    var modalMessage: InAppMessagingModalDisplay
    var delegate: InAppMessagingDisplayDelegate

    var body: some View {
      VStack {
        if let imageData = modalMessage.imageData?.imageRawData,
          let image = UIImage(data: imageData) {
          Image(uiImage: image)
        }
        Text(modalMessage.title).padding(4)
        if let bodyText = modalMessage.bodyText {
          Text(bodyText).padding(4)
        }
        actionButton(modalMessage: modalMessage, delegate: delegate).padding(4)
        dismissButton(modalMessage: modalMessage, delegate: delegate).padding(4)
      }
      .background(Color.white)
      .border(Color.black)
      .cornerRadius(4)
    }

    @ViewBuilder
    func actionButton(modalMessage: InAppMessagingModalDisplay,
                      delegate: InAppMessagingDisplayDelegate) -> some View {
      if let button = modalMessage.actionButton {
        Button(action: {
          if let actionURL = modalMessage.actionURL {
            let action = InAppMessagingAction(actionText: button.buttonText,
                                              actionURL: actionURL)
            delegate.messageClicked?(modalMessage, with: action)
          } else {
            delegate.messageDismissed?(modalMessage, dismissType: .typeUserTapClose)
          }
        }) {
          Text(button.buttonText)
        }
      }
      EmptyView()
    }

    // Need a dismiss button for the case where there's an action button with an action URL. Otherwise
    // user would be forced into a clickthrough.
    @ViewBuilder
    func dismissButton(modalMessage: InAppMessagingModalDisplay,
                       delegate: InAppMessagingDisplayDelegate) -> some View {
      if let _ = modalMessage.actionButton, modalMessage.actionURL != nil {
        Button(action: {
          delegate.messageDismissed?(modalMessage, dismissType: .typeUserTapClose)
        }) {
          Text("Dismiss")
        }
      }
      EmptyView()
    }
  }
}
