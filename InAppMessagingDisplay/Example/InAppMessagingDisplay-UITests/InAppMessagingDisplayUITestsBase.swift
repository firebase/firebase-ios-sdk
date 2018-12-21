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

class InAppMessagingDisplayUITestsBase: XCTestCase {
  func waitForElementToAppear(_ element: XCUIElement, _ timeoutInSeconds: TimeInterval = 60) {
    let existsPredicate = NSPredicate(format: "exists == true")
    expectation(for: existsPredicate, evaluatedWith: element, handler: nil)
    waitForExpectations(timeout: timeoutInSeconds, handler: nil)
  }

  func waitForElementToDisappear(_ element: XCUIElement, _ timeoutInSeconds: TimeInterval = 60) {
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
    return uiElement.exists && uiElement.frame.size.height > 0.1 && uiElement.frame.size.width > 0.1
  }
}
