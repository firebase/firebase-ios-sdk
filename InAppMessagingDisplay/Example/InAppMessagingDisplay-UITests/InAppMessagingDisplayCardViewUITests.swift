//
//  InAppMessagingDisplayCardViewUITests.swift
//  InAppMessagingDisplay-UITests
//
//  Created by Chris Tibbs on 5/1/19.
//  Copyright © 2019 Google. All rights reserved.
//

import XCTest

class InAppMessagingDisplayCardViewUITests: InAppMessagingDisplayUITestsBase {
  var app: XCUIApplication!
  var verificationLabel: XCUIElement!
  
  var messageCardView: XCUIElement!
  var cardImageView: XCUIElement!
  var cardTitleLabel: XCUIElement!
  var cardBodyTextView: XCUIElement!
  var cardPrimaryActionButton: XCUIElement!
  var cardSecondaryActionButton: XCUIElement!
  
  var onScreenElements : [XCUIElement]!

    override func setUp() {
      super.setUp()
      
      app = XCUIApplication()
      
      verificationLabel = app.staticTexts["verification-label-modal"]
      
      messageCardView = app.otherElements["message-card-view"]
      cardImageView = app.images["card-image-view"]
      cardTitleLabel = app.staticTexts["card-title-label"]
      cardBodyTextView = app.textViews["card-body-text-view"]
      cardPrimaryActionButton = app.buttons["card-primary-action-button"]
      cardSecondaryActionButton = app.buttons["card-secondary-action-button"]
      
      onScreenElements = [
        cardImageView,
        cardTitleLabel,
        cardBodyTextView,
        cardPrimaryActionButton,
        cardSecondaryActionButton
      ]
      
      continueAfterFailure = false
      app.launch()
    }

  func testRegularOneButtonWithBothImages() {
    app.tabBars.buttons["Card Messages"].tap()
    app.buttons["Regular one button with both images"].tap()
    waitForElementToAppear(messageCardView)
    verifyOnScreenElementsExcluding(excluding: [cardSecondaryActionButton])
    cardPrimaryActionButton.tap()
    waitForElementToDisappear(messageCardView)
    XCTAssertTrue(verificationLabel.label.contains("clicked"))
  }
  
  func testRegularOneButtonWithOnlyPortrait() {
    app.tabBars.buttons["Card Messages"].tap()
    app.buttons["Regular one button with only portrait"].tap()
    waitForElementToAppear(messageCardView)
    verifyOnScreenElementsExcluding(excluding: [cardSecondaryActionButton])
    cardPrimaryActionButton.tap()
    waitForElementToDisappear(messageCardView)
    XCTAssertTrue(verificationLabel.label.contains("clicked"))
  }
  
  func testRegularTwoButtonWithBothImages() {
    app.tabBars.buttons["Card Messages"].tap()
    app.buttons["Regular two button with both images"].tap()
    waitForElementToAppear(messageCardView)
    verifyOnScreenElementsExcluding(excluding: [])
    cardSecondaryActionButton.tap()
    waitForElementToDisappear(messageCardView)
    XCTAssertTrue(verificationLabel.label.contains("dismissed"))
  }
  
  func testLongTitleRegularBody() {
    app.tabBars.buttons["Card Messages"].tap()
    app.buttons["Long title, regular body"].tap()
    waitForElementToAppear(messageCardView)
    verifyOnScreenElementsExcluding(excluding: [])
    cardSecondaryActionButton.tap()
    waitForElementToDisappear(messageCardView)
    XCTAssertTrue(verificationLabel.label.contains("dismissed"))
  }
  
  func testRegularTitleLongBody() {
    app.tabBars.buttons["Card Messages"].tap()
    app.buttons["Regular title, long body"].tap()
    waitForElementToAppear(messageCardView)
    verifyOnScreenElementsExcluding(excluding: [])
    cardSecondaryActionButton.tap()
    waitForElementToDisappear(messageCardView)
    XCTAssertTrue(verificationLabel.label.contains("dismissed"))
  }
  
  func testLongTitleNoBody() {
    app.tabBars.buttons["Card Messages"].tap()
    app.buttons["Long title, no body"].tap()
    waitForElementToAppear(messageCardView)
    verifyOnScreenElementsExcluding(excluding: [cardBodyTextView])
    cardSecondaryActionButton.tap()
    waitForElementToDisappear(messageCardView)
    XCTAssertTrue(verificationLabel.label.contains("dismissed"))
  }
  
  func testLongPrimaryButton() {
    app.tabBars.buttons["Card Messages"].tap()
    app.buttons["Long primary button"].tap()
    waitForElementToAppear(messageCardView)
    verifyOnScreenElementsExcluding(excluding: [])
    cardSecondaryActionButton.tap()
    waitForElementToDisappear(messageCardView)
    XCTAssertTrue(verificationLabel.label.contains("dismissed"))
  }
  
  func testLongSecondaryButton() {
    app.tabBars.buttons["Card Messages"].tap()
    app.buttons["Long secondary button"].tap()
    waitForElementToAppear(messageCardView)
    verifyOnScreenElementsExcluding(excluding: [])
    cardPrimaryActionButton.tap()
    waitForElementToDisappear(messageCardView)
    XCTAssertTrue(verificationLabel.label.contains("clicked"))
  }
  
  func testSmallImage() {
    app.tabBars.buttons["Card Messages"].tap()
    app.buttons["Small image"].tap()
    waitForElementToAppear(messageCardView)
    verifyOnScreenElementsExcluding(excluding: [cardSecondaryActionButton])
    cardPrimaryActionButton.tap()
    waitForElementToDisappear(messageCardView)
    XCTAssertTrue(verificationLabel.label.contains("clicked"))
  }
  
  func testHugeImage() {
    app.tabBars.buttons["Card Messages"].tap()
    app.buttons["Huge image"].tap()
    waitForElementToAppear(messageCardView)
    verifyOnScreenElementsExcluding(excluding: [cardSecondaryActionButton])
    cardPrimaryActionButton.tap()
    waitForElementToDisappear(messageCardView)
    XCTAssertTrue(verificationLabel.label.contains("clicked"))
  }
  
  func verifyOnScreenElementsExcluding(excluding: [XCUIElement]) {
    let orientantions = [UIDeviceOrientation.portrait, UIDeviceOrientation.landscapeLeft]
    for orientation in orientantions {
      XCUIDevice.shared.orientation = orientation
      
      for element in onScreenElements {
        if !excluding.contains(element) {
          break
        }
        
        XCTAssert(isUIElementWithinUIWindow(element))
        if element != messageCardView {
          XCTAssert(childFrameWithinParentBound(parent: messageCardView, child: element))
        }
      }
    }
  }
}
