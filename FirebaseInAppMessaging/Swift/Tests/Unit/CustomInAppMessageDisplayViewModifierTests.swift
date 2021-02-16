// Tests.

import XCTest

@testable import FirebaseInAppMessaging
@testable import FirebaseInAppMessagingSwift

class DelegateBridgeTests: XCTestCase {
  var delegateBridge = DelegateBridge()

  func testClearsInAppMessageOnDismiss() {
    let inAppMessage = MockFIAM(messageID: "messageID")
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
    let inAppMessage = MockFIAM(messageID: "messageID")
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

  class MockFIAM: InAppMessagingDisplayMessage {
    init(messageID: String) {
      super.init(messageID: messageID,
                 campaignName: "testCampaign",
                 renderAsTestMessage: false,
                 messageType: .card,
                 triggerType: .onAppForeground)
    }
  }
}
