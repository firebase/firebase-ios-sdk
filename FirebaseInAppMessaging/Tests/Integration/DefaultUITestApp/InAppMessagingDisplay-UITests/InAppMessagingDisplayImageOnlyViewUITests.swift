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

class InAppMessagingImageOnlyViewUITests: InAppMessagingDisplayUITestsBase {
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
    verificationLabel = app.staticTexts["verification-label-image-only"]
  }

  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.
    super.tearDown()
  }

  func testImageOnlyView() {
    app.tabBars.buttons["Image Only Messages"].tap()

    let imageView = app.images["image-view-in-image-only-view"]
    let closeButton = app.buttons["close-button"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]
    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation
      app.buttons["Show Regular Image Only View"].tap()

      waitForElementToAppear(closeButton)
      XCTAssert(isElementExistentAndHavingSize(imageView))
      XCTAssert(isUIElementWithinUIWindow(imageView))

      imageView.tap()
      waitForElementToDisappear(imageView)
      let labelValue = verificationLabel.label
      XCTAssertTrue(labelValue.contains("clicked"))
    }
  }

  func testImageOnlyViewWithLargeImageDimension() {
    app.tabBars.buttons["Image Only Messages"].tap()

    let imageView = app.images["image-view-in-image-only-view"]
    let closeButton = app.buttons["close-button"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]
    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation
      app.buttons["High Dimension Image"].tap()

      // wait time longer due to large image
      waitForElementToAppear(closeButton, 30)

      XCTAssert(isElementExistentAndHavingSize(imageView))
      XCTAssert(isUIElementWithinUIWindow(imageView))

      app.buttons["close-button"].tap()
      waitForElementToDisappear(imageView)

      let labelValue = verificationLabel.label
      XCTAssertTrue(labelValue.contains("dismissed"))
    }
  }

  func testImageOnlyViewWithLowImageDimension() {
    app.tabBars.buttons["Image Only Messages"].tap()

    let imageView = app.images["image-view-in-image-only-view"]
    let closeButton = app.buttons["close-button"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]
    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation
      app.buttons["Low Dimension Image"].tap()

      // wait time longer due to large image
      waitForElementToAppear(closeButton, 30)

      XCTAssert(isElementExistentAndHavingSize(imageView))
      XCTAssert(isUIElementWithinUIWindow(imageView))

      app.buttons["close-button"].tap()
      waitForElementToDisappear(imageView)
    }
  }

  func testImageOnlyViewWithWideImage() {
    app.tabBars.buttons["Image Only Messages"].tap()

    let imageView = app.images["image-view-in-image-only-view"]
    let closeButton = app.buttons["close-button"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]
    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation
      app.buttons["Wide Image"].tap()

      // wait time longer due to large image
      waitForElementToAppear(closeButton, 30)

      XCTAssert(isElementExistentAndHavingSize(imageView))
      XCTAssert(isUIElementWithinUIWindow(imageView))

      app.buttons["close-button"].tap()
      waitForElementToDisappear(imageView)
    }
  }

  func testImageOnlyViewWithNarrowImage() {
    app.tabBars.buttons["Image Only Messages"].tap()

    let imageView = app.images["image-view-in-image-only-view"]
    let closeButton = app.buttons["close-button"]

    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]
    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation
      app.buttons["Narrow Image"].tap()

      // wait time longer due to large image
      waitForElementToAppear(closeButton, 30)

      XCTAssert(isElementExistentAndHavingSize(imageView))
      XCTAssert(isUIElementWithinUIWindow(imageView))

      app.buttons["close-button"].tap()
      waitForElementToDisappear(imageView)
    }
  }
}
