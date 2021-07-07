//
//  ModalInAppMessageView.swift
//  FIAMSwiftUI
//
//  Created by Chris Tibbs on 7/7/21.
//

import SwiftUI
import FirebaseInAppMessaging
import FirebaseInAppMessagingSwift

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
        Text(button.buttonText).bold()
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
        Text("Dismiss").bold()
      }
    }
    EmptyView()
  }

  struct ModalInAppMessageView_Previews: PreviewProvider {
    static var previews: some View {
      let modalMessage = InAppMessagingPreviewHelpers.modalMessage()
      return ModalInAppMessageView(modalMessage: modalMessage,
                                   delegate: InAppMessagingPreviewHelpers.Delegate())
    }
  }
}
