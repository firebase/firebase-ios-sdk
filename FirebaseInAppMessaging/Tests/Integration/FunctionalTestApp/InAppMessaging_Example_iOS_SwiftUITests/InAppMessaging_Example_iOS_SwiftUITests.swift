/*
 * Copyright 2017 Google
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

class InAppMessaging_Example_iOS_SwiftUITests: XCTestCase {
  override func setUp() {
    super.setUp()
    continueAfterFailure = false
    let app = XCUIApplication()
    setupSnapshot(app)
    app.launch()
  }

  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.
    XCUIDevice.shared.orientation = .portrait
    super.tearDown()
  }

  func waitForElementToAppear(_ element: XCUIElement, _ timeoutInSeconds: TimeInterval = 5) {
    let existsPredicate = NSPredicate(format: "exists == true")
    expectation(for: existsPredicate, evaluatedWith: element, handler: nil)
    waitForExpectations(timeout: timeoutInSeconds, handler: nil)
  }

  func waitForElementToDisappear(_ element: XCUIElement, _ timeoutInSeconds: TimeInterval = 5) {
    let existsPredicate = NSPredicate(format: "exists == false")
    expectation(for: existsPredicate, evaluatedWith: element, handler: nil)
    waitForExpectations(timeout: timeoutInSeconds, handler: nil)
  }

  func childFrameWithinParentBound(parent: XCUIElement, child: XCUIElement) -> Bool {
    return parent.frame.contains(child.frame)
  }

  func isUIElementWithinUIWindow(_ uiElement: XCUIElement) -> Bool {
    let app = XCUIApplication()
    let window = app.windows.element(boundBy: 0)
    return window.frame.contains(uiElement.frame)
  }

  func isElementExistentAndHavingSize(_ uiElement: XCUIElement) -> Bool {
    // on iOS 9.3 for a XCUIElement whose height or width <=0, uiElement.exists still returns true
    // on iOS 10.3, for such an element uiElement.exists returns false
    // this function is to handle the existence (in our semanatic visible) testing for both cases
    return uiElement.exists && uiElement.frame.size.height > 0 && uiElement.frame.size.width > 0
  }

  func testNormalModalView() {
    let app = XCUIApplication()
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

      snapshot("in-app-regular-modal-view-\(orientation.rawValue)")

      XCTAssert(isElementExistentAndHavingSize(actionButton))
      XCTAssert(isElementExistentAndHavingSize(imageView))
      XCTAssert(isElementExistentAndHavingSize(messageCardView))
      XCTAssert(isElementExistentAndHavingSize(closeButton))

      XCTAssert(isUIElementWithinUIWindow(messageCardView))
      XCTAssert(childFrameWithinParentBound(parent: messageCardView, child: actionButton))

      app.buttons["close-button"].tap()
      waitForElementToDisappear(messageCardView)
    }
  }

  func testModalViewWithWideImage() {
    let app = XCUIApplication()
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

      snapshot("in-app-regular-modal-view-with-wider-image-\(orientation.rawValue)")

      XCTAssert(isElementExistentAndHavingSize(actionButton))
      XCTAssert(isElementExistentAndHavingSize(imageView))
      XCTAssert(isElementExistentAndHavingSize(messageCardView))
      XCTAssert(isElementExistentAndHavingSize(closeButton))

      XCTAssert(isUIElementWithinUIWindow(messageCardView))
      XCTAssert(childFrameWithinParentBound(parent: messageCardView, child: actionButton))

      app.buttons["close-button"].tap()
      waitForElementToDisappear(messageCardView)
    }
  }

  func testModalViewWithNarrowImage() {
    let app = XCUIApplication()
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

      snapshot("in-app-regular-modal-view-with-narrow-image-\(orientation.rawValue)")

      XCTAssert(isElementExistentAndHavingSize(actionButton))
      XCTAssert(isElementExistentAndHavingSize(imageView))
      XCTAssert(isElementExistentAndHavingSize(messageCardView))
      XCTAssert(isElementExistentAndHavingSize(closeButton))

      XCTAssert(isUIElementWithinUIWindow(messageCardView))
      XCTAssert(childFrameWithinParentBound(parent: messageCardView, child: actionButton))

      app.buttons["close-button"].tap()
      waitForElementToDisappear(messageCardView)
    }
  }

  func testNormalBannerView() {
    let app = XCUIApplication()
    app.tabBars.buttons["Banner Messages"].tap()

    let titleElement = app.staticTexts["banner-message-title-view"]
    let imageView = app.images["banner-image-view"]
    let bodyElement = app.staticTexts["banner-body-label"]
    let bannerUIView = app.otherElements["banner-mode-uiview"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]
    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation

      app.buttons["Show Regular Banner View"].tap()

      waitForElementToAppear(bannerUIView)

      snapshot("in-app-regular-banner-view-\(orientation.rawValue)")

      XCTAssert(isElementExistentAndHavingSize(imageView))
      XCTAssert(isElementExistentAndHavingSize(titleElement))
      XCTAssert(isElementExistentAndHavingSize(bodyElement))

      bannerUIView.swipeUp()

      waitForElementToDisappear(bannerUIView)
    }
  }

  func testBannerViewAutoDismiss() {
    let app = XCUIApplication()
    app.tabBars.buttons["Banner Messages"].tap()

    let titleElement = app.staticTexts["banner-message-title-view"]
    let imageView = app.images["banner-image-view"]
    let bodyElement = app.staticTexts["banner-body-label"]
    let bannerUIView = app.otherElements["banner-mode-uiview"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]
    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation

      app.buttons["Banner View With Short Auto Dismiss"].tap()

      waitForElementToAppear(bannerUIView)

      XCTAssert(isElementExistentAndHavingSize(imageView))
      XCTAssert(isElementExistentAndHavingSize(titleElement))
      XCTAssert(isElementExistentAndHavingSize(bodyElement))

      // without user action, the banner is dismissed quickly in this test setup
      waitForElementToDisappear(bannerUIView, 15)
    }
  }

  func testBannerViewWithoutImage() {
    let app = XCUIApplication()
    app.tabBars.buttons["Banner Messages"].tap()

    let titleElement = app.staticTexts["banner-message-title-view"]
    let bodyElement = app.staticTexts["banner-body-label"]
    let bannerUIView = app.otherElements["banner-mode-uiview"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]
    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation
      app.buttons["Without Image"].tap()
      waitForElementToAppear(bannerUIView)

      snapshot("in-app-banner-view-without-image-\(orientation.rawValue)")

      XCTAssert(isElementExistentAndHavingSize(titleElement))
      XCTAssert(isElementExistentAndHavingSize(bodyElement))

      bannerUIView.swipeUp()
      waitForElementToDisappear(bannerUIView)
    }
  }

  func testBannerViewWithLongTitle() {
    let app = XCUIApplication()
    app.tabBars.buttons["Banner Messages"].tap()

    let titleElement = app.staticTexts["banner-message-title-view"]
    let imageView = app.images["banner-image-view"]
    let bodyElement = app.staticTexts["banner-body-label"]
    let bannerUIView = app.otherElements["banner-mode-uiview"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]
    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation
      app.buttons["With Long Title"].tap()
      waitForElementToAppear(bannerUIView)

      snapshot("in-app-banner-view-with-long-title-\(orientation.rawValue)")

      XCTAssert(isElementExistentAndHavingSize(imageView))
      XCTAssert(isElementExistentAndHavingSize(titleElement))
      XCTAssert(isElementExistentAndHavingSize(bodyElement))

      bannerUIView.swipeUp()
      waitForElementToDisappear(bannerUIView)
    }
  }

  func testBannerViewWithWideImage() {
    let app = XCUIApplication()
    app.tabBars.buttons["Banner Messages"].tap()

    let titleElement = app.staticTexts["banner-message-title-view"]
    let imageView = app.images["banner-image-view"]
    let bodyElement = app.staticTexts["banner-body-label"]
    let bannerUIView = app.otherElements["banner-mode-uiview"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]
    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation
      app.buttons["With Wide Image"].tap()
      waitForElementToAppear(bannerUIView)

      snapshot("in-app-banner-view-with-wide-image-\(orientation.rawValue)")

      XCTAssert(isElementExistentAndHavingSize(imageView))
      XCTAssert(isElementExistentAndHavingSize(titleElement))
      XCTAssert(isElementExistentAndHavingSize(bodyElement))

      bannerUIView.swipeUp()
      waitForElementToDisappear(bannerUIView)
    }
  }

  func testBannerViewWithThinImage() {
    let app = XCUIApplication()
    app.tabBars.buttons["Banner Messages"].tap()

    let titleElement = app.staticTexts["banner-message-title-view"]
    let imageView = app.images["banner-image-view"]
    let bodyElement = app.staticTexts["banner-body-label"]
    let bannerUIView = app.otherElements["banner-mode-uiview"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]
    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation
      app.buttons["With Thin Image"].tap()
      waitForElementToAppear(bannerUIView)

      snapshot("in-app-banner-view-with-thing-image-\(orientation.rawValue)")

      XCTAssert(isElementExistentAndHavingSize(imageView))
      XCTAssert(isElementExistentAndHavingSize(titleElement))
      XCTAssert(isElementExistentAndHavingSize(bodyElement))

      bannerUIView.swipeUp()
      waitForElementToDisappear(bannerUIView)
    }
  }

  func testBannerViewWithLargeBody() {
    let app = XCUIApplication()
    app.tabBars.buttons["Banner Messages"].tap()

    let titleElement = app.staticTexts["banner-message-title-view"]
    let imageView = app.images["banner-image-view"]
    let bodyElement = app.staticTexts["banner-body-label"]
    let bannerUIView = app.otherElements["banner-mode-uiview"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]
    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation
      app.buttons["With Large Body Text"].tap()
      waitForElementToAppear(bannerUIView)

      snapshot("in-app-banner-view-with-long-body-\(orientation.rawValue)")

      XCTAssert(isElementExistentAndHavingSize(imageView))
      XCTAssert(isElementExistentAndHavingSize(titleElement))
      XCTAssert(isElementExistentAndHavingSize(bodyElement))

      bannerUIView.swipeUp()
      waitForElementToDisappear(bannerUIView)
    }
  }

  func testImageOnlyView() {
    let app = XCUIApplication()
    app.tabBars.buttons["Image Only Messages"].tap()

    let imageView = app.images["image-view-in-image-only-view"]
    let closeButton = app.buttons["close-button"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]
    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation
      app.buttons["Show Regular Image Only View"].tap()

      waitForElementToAppear(closeButton)
      snapshot("in-app-regular-image-only-view-\(orientation.rawValue)")

      XCTAssert(isElementExistentAndHavingSize(imageView))
      XCTAssert(isUIElementWithinUIWindow(imageView))

      app.buttons["close-button"].tap()
      waitForElementToDisappear(imageView)
    }
  }

  func testImageOnlyViewWithLargeImageDimension() {
    let app = XCUIApplication()
    app.tabBars.buttons["Image Only Messages"].tap()

    let imageView = app.images["image-view-in-image-only-view"]
    let closeButton = app.buttons["close-button"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]
    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation
      app.buttons["High Dimension Image"].tap()

      // wait time longer due to large image
      waitForElementToAppear(closeButton, 10)

      snapshot("in-app-large-image-only-view-high-dimension-\(orientation.rawValue)")
      XCTAssert(isElementExistentAndHavingSize(imageView))
      XCTAssert(isUIElementWithinUIWindow(imageView))

      app.buttons["close-button"].tap()
      waitForElementToDisappear(imageView)
    }
  }

  func testImageOnlyViewWithLowImageDimension() {
    let app = XCUIApplication()
    app.tabBars.buttons["Image Only Messages"].tap()

    let imageView = app.images["image-view-in-image-only-view"]
    let closeButton = app.buttons["close-button"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]
    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation
      app.buttons["Low Dimension Image"].tap()

      // wait time longer due to large image
      waitForElementToAppear(closeButton, 10)

      snapshot("in-app-large-image-only-view-low-dimension-\(orientation.rawValue)")
      XCTAssert(isElementExistentAndHavingSize(imageView))
      XCTAssert(isUIElementWithinUIWindow(imageView))

      app.buttons["close-button"].tap()
      waitForElementToDisappear(imageView)
    }
  }

  func testModalViewWithoutImage() {
    let app = XCUIApplication()
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

      snapshot("in-app-no-image-modal-view-\(orientation.rawValue)")
      XCTAssert(isElementExistentAndHavingSize(actionButton))
      XCTAssert(isElementExistentAndHavingSize(closeButton))
      XCTAssertFalse(isElementExistentAndHavingSize(imageView))

      XCTAssert(isElementExistentAndHavingSize(messageCardView))

      XCTAssert(isUIElementWithinUIWindow(messageCardView))
      XCTAssert(childFrameWithinParentBound(parent: messageCardView, child: actionButton))

      app.buttons["close-button"].tap()
      waitForElementToDisappear(messageCardView)
    }
  }

  func testModalViewWithoutImageOrActionButton() {
    let app = XCUIApplication()
    app.tabBars.buttons["Modal Messages"].tap()

    let messageCardView = app.otherElements["message-card-view"]
    let closeButton = app.buttons["close-button"]
    let actionButton = app.buttons["message-action-button"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]
    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation
      app.buttons["Without Image or Action Button"].tap()

      waitForElementToAppear(closeButton)

      snapshot("in-app-no-image-no-button-modal-view-\(orientation.rawValue)")
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
    let app = XCUIApplication()
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

      snapshot("in-app-no-action-button-moal-view-\(orientation.rawValue)")
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
    let app = XCUIApplication()
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

      snapshot("in-app-long-title-modal-view-\(orientation.rawValue)")
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

  func testModalViewWithLongMessageBody() {
    let app = XCUIApplication()
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

      snapshot("in-app-long-body-modal-view-\(orientation.rawValue)")
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

  func testModalViewWithLongMessageTitleAndMessageBody() {
    let app = XCUIApplication()
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

      snapshot("in-app-long-title-and-body-modal-view-\(orientation.rawValue)")
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

      snapshot("in-app-long-title-and-body-no-image-modal-view-\(orientation.rawValue)")
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

      snapshot("in-app-long-title-no-image-body-button-modal-view-\(orientation.rawValue)")
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
