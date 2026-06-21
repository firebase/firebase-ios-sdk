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

import XCTest

@testable import FirebaseInAppMessaging

class DelegateBridgeTests: XCTestCase {
  var delegateBridge = DelegateBridge()

  func testClearsInAppMessageOnDismiss() {
    let inAppMessage = InAppMessagingDisplayMessage(
      messageID: "messageID",
      campaignName: "testCampaign",
      renderAsTestMessage: false,
      messageType: .card,
      triggerType: .onAppForeground
    )
    delegateBridge.displayMessage(inAppMessage, displayDelegate: TestDelegate())

    DispatchQueue.main.async {
      XCTAssertNotNil(self.delegateBridge.inAppMessageData)
    }

    delegateBridge.messageDismissed(inAppMessage, dismissType: .typeUserTapClose)

    DispatchQueue.main.async {
      XCTAssertNil(self.delegateBridge.inAppMessageData)
    }
  }

  func testClearsInAppMessageOnClick() {
    let inAppMessage = InAppMessagingDisplayMessage(
      messageID: "messageID",
      campaignName: "testCampaign",
      renderAsTestMessage: false,
      messageType: .card,
      triggerType: .onAppForeground
    )
    delegateBridge.displayMessage(inAppMessage, displayDelegate: TestDelegate())

    DispatchQueue.main.async {
      XCTAssertNotNil(self.delegateBridge.inAppMessageData)
    }

    delegateBridge.messageClicked(inAppMessage,
                                  with: InAppMessagingAction(actionText: "test",
                                                             actionURL: URL(
                                                               string: "http://www.test.com"
                                                             )))

    DispatchQueue.main.async {
      XCTAssertNil(self.delegateBridge.inAppMessageData)
    }
  }

  class TestDelegate: NSObject, InAppMessagingDisplayDelegate {}
}
