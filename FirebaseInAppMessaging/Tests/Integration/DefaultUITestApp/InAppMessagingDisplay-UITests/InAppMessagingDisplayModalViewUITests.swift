/*
 * Copyright 2018 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import XCTest

class InAppMessagingDisplayModalViewUITests: InAppMessagingDisplayUITestsBase {
  var app: XCUIApplication!
  var verificationLabel: XCUIElement!

  override func setUp() {
    super.setUp()

    // Put setup code here. This method is called before the invocation of each test method in the
    // class.

    // In UI tests it is usually best to stop immediately when a failure occurs.
    continueAfterFailure = false
    // UI tests must launch the application that they test. Doing this in setup will make sure it
    // happens for each test method.
    XCUIApplication().launch()

    app = XCUIApplication()
    verificationLabel = app.staticTexts["verification-label-modal"]

    // In UI tests it’s important to set the initial state - such as interface orientation -
    // required for your tests before they run. The setUp method is a good place to do this.
  }

  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.
    super.tearDown()
  }

  func testNormalModalView() {
    app.tabBars.buttons["Modal Messages"].tap()

    let messageCardView = app.otherElements["message-card-view"]
    let closeButton = app.buttons["close-button"]
    let imageView = app.images["modal-image-view"]
    let actionButton = app.buttons["message-action-button"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]

    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation
      app.buttons["Regular"].tap()
      waitForElementToAppear(closeButton)
      XCTAssert(isElementExistentAndHavingSize(actionButton))
      XCTAssert(isElementExistentAndHavingSize(imageView))
      XCTAssert(isElementExistentAndHavingSize(messageCardView))
      XCTAssert(isElementExistentAndHavingSize(closeButton))
      XCTAssert(isUIElementWithinUIWindow(messageCardView))
      XCTAssert(childFrameWithinParentBound(parent: messageCardView, child: actionButton))

      if orientation == UIDeviceOrientation.portrait {
        actionButton.tap()
      } else {
        closeButton.tap()
      }
      waitForElementToDisappear(messageCardView)

      let labelValue = verificationLabel.label

      if orientation == UIDeviceOrientation.portrait {
        XCTAssertTrue(labelValue.contains("clicked"))
      } else {
        XCTAssertTrue(labelValue.contains("dismissed"))
      }
    }
  }

  func testModalViewWithWideImage() {
    app.tabBars.buttons["Modal Messages"].tap()

    let messageCardView = app.otherElements["message-card-view"]
    let closeButton = app.buttons["close-button"]
    let imageView = app.images["modal-image-view"]
    let actionButton = app.buttons["message-action-button"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]
    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation

      app.buttons["Wide Image"].tap()

      waitForElementToAppear(closeButton)

      XCTAssert(isElementExistentAndHavingSize(actionButton))
      XCTAssert(isElementExistentAndHavingSize(imageView))
      XCTAssert(isElementExistentAndHavingSize(messageCardView))
      XCTAssert(isElementExistentAndHavingSize(closeButton))

      XCTAssert(isUIElementWithinUIWindow(messageCardView))
      XCTAssert(childFrameWithinParentBound(parent: messageCardView, child: actionButton))

      app.buttons["close-button"].tap()
      waitForElementToDisappear(messageCardView)

      let labelValue = verificationLabel.label
      XCTAssertTrue(labelValue.contains("dismissed"))
    }
  }

  func testModalViewWithNarrowImage() {
    app.tabBars.buttons["Modal Messages"].tap()

    let messageCardView = app.otherElements["message-card-view"]
    let closeButton = app.buttons["close-button"]
    let imageView = app.images["modal-image-view"]
    let actionButton = app.buttons["message-action-button"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]
    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation

      app.buttons["Thin Image"].tap()

      waitForElementToAppear(closeButton)

      XCTAssert(isElementExistentAndHavingSize(actionButton))
      XCTAssert(isElementExistentAndHavingSize(imageView))
      XCTAssert(isElementExistentAndHavingSize(messageCardView))
      XCTAssert(isElementExistentAndHavingSize(closeButton))

      XCTAssert(isUIElementWithinUIWindow(messageCardView))
      XCTAssert(childFrameWithinParentBound(parent: messageCardView, child: actionButton))

      actionButton.tap()
      waitForElementToDisappear(messageCardView)

      let labelValue = verificationLabel.label
      XCTAssertTrue(labelValue.contains("clicked"))
    }
  }

  func testModalViewWithoutImage() {
    app.tabBars.buttons["Modal Messages"].tap()

    let messageCardView = app.otherElements["message-card-view"]
    let closeButton = app.buttons["close-button"]
    let actionButton = app.buttons["message-action-button"]
    let imageView = app.images["modal-image-view"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]
    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation
      app.buttons["Without Image"].tap()
      waitForElementToAppear(closeButton)

      XCTAssert(isElementExistentAndHavingSize(actionButton))
      XCTAssert(isElementExistentAndHavingSize(closeButton))
      XCTAssertFalse(isElementExistentAndHavingSize(imageView))

      XCTAssert(isElementExistentAndHavingSize(messageCardView))

      XCTAssert(isUIElementWithinUIWindow(messageCardView))
      XCTAssert(childFrameWithinParentBound(parent: messageCardView, child: actionButton))

      app.buttons["close-button"].tap()
      waitForElementToDisappear(messageCardView)

      let labelValue = verificationLabel.label
      XCTAssertTrue(labelValue.contains("dismissed"))
    }
  }

  func testModalViewWithoutImageOrActionButton() {
    app.tabBars.buttons["Modal Messages"].tap()

    let messageCardView = app.otherElements["message-card-view"]
    let closeButton = app.buttons["close-button"]
    let actionButton = app.buttons["message-action-button"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]
    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation
      app.buttons["Without Image or Action Button"].tap()

      waitForElementToAppear(closeButton)

      XCTAssertFalse(isElementExistentAndHavingSize(actionButton))
      XCTAssert(isElementExistentAndHavingSize(closeButton))
      XCTAssert(isElementExistentAndHavingSize(messageCardView))

      XCTAssert(isUIElementWithinUIWindow(messageCardView))

      app.buttons["close-button"].tap()
      waitForElementToDisappear(messageCardView)
      XCUIDevice.shared.orientation = .portrait
    }
  }

  func testModalViewWithoutActionButton() {
    app.tabBars.buttons["Modal Messages"].tap()

    let messageCardView = app.otherElements["message-card-view"]
    let closeButton = app.buttons["close-button"]
    let imageView = app.images["modal-image-view"]
    let actionButton = app.buttons["message-action-button"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]

    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation
      app.buttons["Without Action Button"].tap()
      waitForElementToAppear(closeButton)

      XCTAssertFalse(isElementExistentAndHavingSize(actionButton))
      XCTAssert(isElementExistentAndHavingSize(closeButton))
      XCTAssert(isElementExistentAndHavingSize(messageCardView))
      XCTAssert(isElementExistentAndHavingSize(imageView))

      XCTAssert(isUIElementWithinUIWindow(messageCardView))

      app.buttons["close-button"].tap()
      waitForElementToDisappear(messageCardView)
    }
  }

  func testModalViewWithLongMessageTitle() {
    app.tabBars.buttons["Modal Messages"].tap()

    let messageCardView = app.otherElements["message-card-view"]
    let closeButton = app.buttons["close-button"]
    let imageView = app.images["modal-image-view"]
    let bodyTextview = app.textViews["message-body-textview"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]

    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation

      app.buttons["Large Title Text"].tap()
      waitForElementToAppear(closeButton)

      let actionButton = app.buttons["message-action-button"]

      XCTAssert(isElementExistentAndHavingSize(actionButton))
      XCTAssert(isElementExistentAndHavingSize(closeButton))
      XCTAssert(isElementExistentAndHavingSize(bodyTextview))
      XCTAssert(isElementExistentAndHavingSize(messageCardView))
      XCTAssert(!isElementExistentAndHavingSize(imageView))

      XCTAssert(isUIElementWithinUIWindow(messageCardView))
      XCTAssert(childFrameWithinParentBound(parent: messageCardView, child: actionButton))
      XCTAssert(childFrameWithinParentBound(parent: messageCardView, child: bodyTextview))
      app.buttons["close-button"].tap()

      waitForElementToDisappear(messageCardView)
    }
  }

  func testModalViewWithLongMessageBody() {
    app.tabBars.buttons["Modal Messages"].tap()

    let messageCardView = app.otherElements["message-card-view"]
    let closeButton = app.buttons["close-button"]
    let imageView = app.images["modal-image-view"]
    let bodyTextview = app.textViews["message-body-textview"]
    let actionButton = app.buttons["message-action-button"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]

    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation

      app.buttons["Large Title Text"].tap()
      waitForElementToAppear(closeButton)

      XCTAssert(isElementExistentAndHavingSize(actionButton))
      XCTAssert(isElementExistentAndHavingSize(closeButton))
      XCTAssert(isElementExistentAndHavingSize(bodyTextview))
      XCTAssert(isElementExistentAndHavingSize(messageCardView))
      XCTAssert(!isElementExistentAndHavingSize(imageView))

      XCTAssert(isUIElementWithinUIWindow(messageCardView))
      XCTAssert(childFrameWithinParentBound(parent: messageCardView, child: actionButton))
      XCTAssert(childFrameWithinParentBound(parent: messageCardView, child: bodyTextview))

      actionButton.tap()

      waitForElementToDisappear(messageCardView)
      let labelValue = verificationLabel.label
      XCTAssertTrue(labelValue.contains("clicked"))
    }
  }

  func testModalViewWithLongMessageTitleAndMessageBody() {
    app.tabBars.buttons["Modal Messages"].tap()

    let messageCardView = app.otherElements["message-card-view"]
    let closeButton = app.buttons["close-button"]
    let imageView = app.images["modal-image-view"]
    let bodyTextview = app.textViews["message-body-textview"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]

    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation

      app.buttons["With Large Title and Body"].tap()
      waitForElementToAppear(closeButton)

      let actionButton = app.buttons["message-action-button"]

      XCTAssert(isElementExistentAndHavingSize(actionButton))
      XCTAssert(isElementExistentAndHavingSize(closeButton))
      XCTAssert(isElementExistentAndHavingSize(bodyTextview))
      XCTAssert(isElementExistentAndHavingSize(messageCardView))
      XCTAssert(isElementExistentAndHavingSize(imageView))

      XCTAssert(isUIElementWithinUIWindow(messageCardView))
      XCTAssert(childFrameWithinParentBound(parent: messageCardView, child: actionButton))
      XCTAssert(childFrameWithinParentBound(parent: messageCardView, child: bodyTextview))
      XCTAssert(childFrameWithinParentBound(parent: messageCardView, child: imageView))

      app.buttons["close-button"].tap()

      waitForElementToDisappear(messageCardView)
    }
  }

  func testModalViewWithLongMessageTitleAndMessageBodyWithoutImage() {
    let app = XCUIApplication()
    app.tabBars.buttons["Modal Messages"].tap()

    let messageCardView = app.otherElements["message-card-view"]
    let closeButton = app.buttons["close-button"]
    let imageView = app.images["modal-image-view"]
    let bodyTextview = app.textViews["message-body-textview"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]

    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation

      app.buttons["With Large Title and Body Without Image"].tap()
      waitForElementToAppear(closeButton)

      let actionButton = app.buttons["message-action-button"]

      XCTAssert(isElementExistentAndHavingSize(actionButton))
      XCTAssert(isElementExistentAndHavingSize(closeButton))
      XCTAssert(isElementExistentAndHavingSize(bodyTextview))
      XCTAssert(isElementExistentAndHavingSize(messageCardView))
      XCTAssert(!isElementExistentAndHavingSize(imageView))

      XCTAssert(isUIElementWithinUIWindow(messageCardView))
      XCTAssert(childFrameWithinParentBound(parent: messageCardView, child: actionButton))
      XCTAssert(childFrameWithinParentBound(parent: messageCardView, child: bodyTextview))

      app.buttons["close-button"].tap()

      waitForElementToDisappear(messageCardView)
    }
  }

  func testModalViewWithLongMessageTitleWithoutBodyWithoutImageWithoutButton() {
    let app = XCUIApplication()
    app.tabBars.buttons["Modal Messages"].tap()

    let messageCardView = app.otherElements["message-card-view"]
    let closeButton = app.buttons["close-button"]
    let imageView = app.images["modal-image-view"]
    let bodyTextview = app.textViews["message-body-textview"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]

    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation

      app.buttons["With Large Title, No Image, No Body and No Button"].tap()
      waitForElementToAppear(closeButton)

      let actionButton = app.buttons["message-action-button"]

      XCTAssert(!isElementExistentAndHavingSize(actionButton))
      XCTAssert(isElementExistentAndHavingSize(closeButton))
      XCTAssert(!isElementExistentAndHavingSize(bodyTextview))
      XCTAssert(isElementExistentAndHavingSize(messageCardView))
      XCTAssert(!isElementExistentAndHavingSize(imageView))

      XCTAssert(isUIElementWithinUIWindow(messageCardView))

      app.buttons["close-button"].tap()

      waitForElementToDisappear(messageCardView)
    }
  }
}
