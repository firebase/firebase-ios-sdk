// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import FirebaseInAppMessaging
import SwiftUI

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
