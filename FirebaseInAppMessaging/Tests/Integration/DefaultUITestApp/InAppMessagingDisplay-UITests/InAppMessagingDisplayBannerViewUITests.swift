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

import Foundation

import XCTest

class InAppMessagingDisplayBannerViewUITests: InAppMessagingDisplayUITestsBase {
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

    // In UI tests it’s important to set the initial state - such as interface orientation -
    // required for your tests before they run. The setUp method is a good place to do this.

    app = XCUIApplication()
    verificationLabel = app.staticTexts["verification-label-banner"]
  }

  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.
    super.tearDown()
  }

  func testNormalBannerView() {
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

      XCTAssert(isElementExistentAndHavingSize(imageView))
      XCTAssert(isElementExistentAndHavingSize(titleElement))
      XCTAssert(isElementExistentAndHavingSize(bodyElement))

      // This also verifies that up-swiping gesture would dismiss
      // the banner view
      bannerUIView.swipeUp()

      waitForElementToDisappear(bannerUIView)

      let labelValue = verificationLabel.label
      XCTAssertTrue(labelValue.contains("dismissed"))
    }
  }

  func testBannerViewWithoutImage() {
    app.tabBars.buttons["Banner Messages"].tap()

    let titleElement = app.staticTexts["banner-message-title-view"]
    let imageViewElement = app.images["banner-image-view"]
    let bodyElement = app.staticTexts["banner-body-label"]
    let bannerUIView = app.otherElements["banner-mode-uiview"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]
    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation
      app.buttons["Without Image"].tap()
      waitForElementToAppear(bannerUIView)

      XCTAssert(isElementExistentAndHavingSize(titleElement))
      XCTAssert(isElementExistentAndHavingSize(bodyElement))
      XCTAssert(!isElementExistentAndHavingSize(imageViewElement))

      bannerUIView.tap()
      waitForElementToDisappear(bannerUIView)

      let labelValue = verificationLabel.label
      XCTAssertTrue(labelValue.contains("clicked"))
    }
  }

  func testBannerViewWithLongTitle() {
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

      XCTAssert(isElementExistentAndHavingSize(imageView))
      XCTAssert(isElementExistentAndHavingSize(titleElement))
      XCTAssert(isElementExistentAndHavingSize(bodyElement))

      bannerUIView.swipeUp()
      waitForElementToDisappear(bannerUIView)
    }
  }

  func testBannerViewWithWideImage() {
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

      XCTAssert(isElementExistentAndHavingSize(imageView))
      XCTAssert(isElementExistentAndHavingSize(titleElement))
      XCTAssert(isElementExistentAndHavingSize(bodyElement))

      bannerUIView.swipeUp()
      waitForElementToDisappear(bannerUIView)
    }
  }

  func testBannerViewWithThinImage() {
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

      XCTAssert(isElementExistentAndHavingSize(imageView))
      XCTAssert(isElementExistentAndHavingSize(titleElement))
      XCTAssert(isElementExistentAndHavingSize(bodyElement))

      bannerUIView.swipeUp()
      waitForElementToDisappear(bannerUIView)
    }
  }

  func testBannerViewWithLargeBody() {
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

      XCTAssert(isElementExistentAndHavingSize(imageView))
      XCTAssert(isElementExistentAndHavingSize(titleElement))
      XCTAssert(isElementExistentAndHavingSize(bodyElement))

      bannerUIView.swipeUp()
      waitForElementToDisappear(bannerUIView)
    }
  }
}
