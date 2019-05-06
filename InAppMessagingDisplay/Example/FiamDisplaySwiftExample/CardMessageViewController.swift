//
//  CardMessageViewController.swift
//  FiamDisplaySwiftExample
//
//  Created by Chris Tibbs on 3/6/19.
//  Copyright © 2019 Google. All rights reserved.
//

import UIKit

class CardMessageViewController: CommonMessageTestVC {
  let displayImpl = InAppMessagingDefaultDisplayImpl()

  @IBOutlet var verifyLabel: UILabel!
  
  override func messageClicked(_ inAppMessage: InAppMessagingDisplayMessage,
                               with action: FIRInAppMessagingAction) {
    super.messageClicked(inAppMessage, with: action)
    verifyLabel.text = "message clicked!"
  }
  
  override func messageDismissed(_ inAppMessage: InAppMessagingDisplayMessage,
                                 dismissType: FIRInAppMessagingDismissType) {
    super.messageDismissed(inAppMessage, dismissType: dismissType)
    verifyLabel.text = "message dismissed!"
  }

  @IBAction func showRegularOneButtonWithBothImages(_ sender: Any) {
    let portraitImageRawData = produceImageOfSize(size: CGSize(width: 300, height: 200))
    let portraitImageData = InAppMessagingImageData(imageURL: "url not important", imageData: portraitImageRawData!)
    
    let landscapeImageRawData = produceImageOfSize(size: CGSize(width: 200, height: 200))
    let landscapeImageData = InAppMessagingImageData(imageURL: "url not important", imageData: landscapeImageRawData!)

    let cardMessage = InAppMessagingCardDisplay(messageID: "testID",
                                                campaignName: "testCampaign",
                                                renderAsTestMessage: false,
                                                triggerType: .onAnalyticsEvent,
                                                titleText: normalMessageTitle,
                                                bodyText: normalMessageBody,
                                                textColor: UIColor.black,
                                                portraitImageData: portraitImageData,
                                                landscapeImageData: landscapeImageData,
                                                backgroundColor: UIColor.white,
                                                primaryActionButton: defaultActionButton,
                                                primaryActionURL: URL(string: "http://google.com")!,
                                                secondaryActionButton: nil,
                                                secondaryActionURL: nil)

    displayImpl.displayMessage(cardMessage, displayDelegate: self)
  }
  
  @IBAction func showRegularOneButtonWithOnlyPortrait(_ sender: Any) {
    let portraitImageRawData = produceImageOfSize(size: CGSize(width: 300, height: 200))
    let portraitImageData = InAppMessagingImageData(imageURL: "url not important", imageData: portraitImageRawData!)

    let cardMessage = InAppMessagingCardDisplay(messageID: "testID",
                                                campaignName: "testCampaign",
                                                renderAsTestMessage: false,
                                                triggerType: .onAnalyticsEvent,
                                                titleText: normalMessageTitle,
                                                bodyText: normalMessageBody,
                                                textColor: UIColor.black,
                                                portraitImageData: portraitImageData,
                                                landscapeImageData: nil,
                                                backgroundColor: UIColor.white,
                                                primaryActionButton: defaultActionButton,
                                                primaryActionURL: URL(string: "http://google.com")!,
                                                secondaryActionButton: nil,
                                                secondaryActionURL: nil)
    
    displayImpl.displayMessage(cardMessage, displayDelegate: self)
  }
  
  @IBAction func showRegularTwoButtonWithBothImages(_ sender: Any) {
    let portraitImageRawData = produceImageOfSize(size: CGSize(width: 300, height: 200))
    let portraitImageData = InAppMessagingImageData(imageURL: "url not important", imageData: portraitImageRawData!)
    
    let landscapeImageRawData = produceImageOfSize(size: CGSize(width: 300, height: 300))
    let landscapeImageData = InAppMessagingImageData(imageURL: "url not important", imageData: landscapeImageRawData!)
    
    let cardMessage = InAppMessagingCardDisplay(messageID: "testID",
                                                campaignName: "testCampaign",
                                                renderAsTestMessage: false,
                                                triggerType: .onAnalyticsEvent,
                                                titleText: normalMessageTitle,
                                                bodyText: normalMessageBody,
                                                textColor: UIColor.black,
                                                portraitImageData: portraitImageData,
                                                landscapeImageData: landscapeImageData,
                                                backgroundColor: UIColor.white,
                                                primaryActionButton: defaultActionButton,
                                                primaryActionURL: URL(string: "http://google.com")!,
                                                secondaryActionButton: defaultSecondaryActionButton,
                                                secondaryActionURL: nil)
    
    displayImpl.displayMessage(cardMessage, displayDelegate: self)
  }
  
  @IBAction func showLongTitleRegularBody(_ sender: Any) {
    let portraitImageRawData = produceImageOfSize(size: CGSize(width: 300, height: 200))
    let portraitImageData = InAppMessagingImageData(imageURL: "url not important", imageData: portraitImageRawData!)
    
    let cardMessage = InAppMessagingCardDisplay(messageID: "testID",
                                                campaignName: "testCampaign",
                                                renderAsTestMessage: false,
                                                triggerType: .onAnalyticsEvent,
                                                titleText: longTitleText,
                                                bodyText: normalMessageBody,
                                                textColor: UIColor.black,
                                                portraitImageData: portraitImageData,
                                                landscapeImageData: nil,
                                                backgroundColor: UIColor.white,
                                                primaryActionButton: defaultActionButton,
                                                primaryActionURL: URL(string: "http://google.com")!,
                                                secondaryActionButton: defaultSecondaryActionButton,
                                                secondaryActionURL: nil)
    
    displayImpl.displayMessage(cardMessage, displayDelegate: self)
  }
  
  @IBAction func showRegularTitleLongBody(_ sender: Any) {
    let portraitImageRawData = produceImageOfSize(size: CGSize(width: 300, height: 200))
    let portraitImageData = InAppMessagingImageData(imageURL: "url not important", imageData: portraitImageRawData!)
    
    let cardMessage = InAppMessagingCardDisplay(messageID: "testID",
                                                campaignName: "testCampaign",
                                                renderAsTestMessage: false,
                                                triggerType: .onAnalyticsEvent,
                                                titleText: normalMessageTitle,
                                                bodyText: longBodyText,
                                                textColor: UIColor.black,
                                                portraitImageData: portraitImageData,
                                                landscapeImageData: nil,
                                                backgroundColor: UIColor.white,
                                                primaryActionButton: defaultActionButton,
                                                primaryActionURL: URL(string: "http://google.com")!,
                                                secondaryActionButton: defaultSecondaryActionButton,
                                                secondaryActionURL: nil)
    
    displayImpl.displayMessage(cardMessage, displayDelegate: self)
  }
  
  @IBAction func showLongTitleNoBody(_ sender: Any) {
    let portraitImageRawData = produceImageOfSize(size: CGSize(width: 300, height: 200))
    let portraitImageData = InAppMessagingImageData(imageURL: "url not important", imageData: portraitImageRawData!)
    
    let cardMessage = InAppMessagingCardDisplay(messageID: "testID",
                                                campaignName: "testCampaign",
                                                renderAsTestMessage: false,
                                                triggerType: .onAnalyticsEvent,
                                                titleText: longTitleText,
                                                bodyText: nil,
                                                textColor: UIColor.black,
                                                portraitImageData: portraitImageData,
                                                landscapeImageData: nil,
                                                backgroundColor: UIColor.white,
                                                primaryActionButton: defaultActionButton,
                                                primaryActionURL: URL(string: "http://google.com")!,
                                                secondaryActionButton: defaultSecondaryActionButton,
                                                secondaryActionURL: nil)
    
    displayImpl.displayMessage(cardMessage, displayDelegate: self)
  }
  
  @IBAction func showLongPrimaryButton(_ sender: Any) {
    let portraitImageRawData = produceImageOfSize(size: CGSize(width: 300, height: 200))
    let portraitImageData = InAppMessagingImageData(imageURL: "url not important", imageData: portraitImageRawData!)
    
    let cardMessage = InAppMessagingCardDisplay(messageID: "testID",
                                                campaignName: "testCampaign",
                                                renderAsTestMessage: false,
                                                triggerType: .onAnalyticsEvent,
                                                titleText: longTitleText,
                                                bodyText: normalMessageBody,
                                                textColor: UIColor.black,
                                                portraitImageData: portraitImageData,
                                                landscapeImageData: nil,
                                                backgroundColor: UIColor.white,
                                                primaryActionButton: longTextButton,
                                                primaryActionURL: URL(string: "http://google.com")!,
                                                secondaryActionButton: defaultSecondaryActionButton,
                                                secondaryActionURL: nil)
    
    displayImpl.displayMessage(cardMessage, displayDelegate: self)
  }
  
  @IBAction func showLongSecondaryButton(_ sender: Any) {
    let portraitImageRawData = produceImageOfSize(size: CGSize(width: 300, height: 200))
    let portraitImageData = InAppMessagingImageData(imageURL: "url not important", imageData: portraitImageRawData!)
    
    let cardMessage = InAppMessagingCardDisplay(messageID: "testID",
                                                campaignName: "testCampaign",
                                                renderAsTestMessage: false,
                                                triggerType: .onAnalyticsEvent,
                                                titleText: longTitleText,
                                                bodyText: normalMessageBody,
                                                textColor: UIColor.black,
                                                portraitImageData: portraitImageData,
                                                landscapeImageData: nil,
                                                backgroundColor: UIColor.white,
                                                primaryActionButton: defaultActionButton,
                                                primaryActionURL: URL(string: "http://google.com")!,
                                                secondaryActionButton: longTextButton,
                                                secondaryActionURL: nil)
    
    displayImpl.displayMessage(cardMessage, displayDelegate: self)
  }
  
  @IBAction func showSmallImage(_ sender: Any) {
    let portraitImageRawData = produceImageOfSize(size: CGSize(width: 30, height: 20))
    let portraitImageData = InAppMessagingImageData(imageURL: "url not important", imageData: portraitImageRawData!)
    
    let cardMessage = InAppMessagingCardDisplay(messageID: "testID",
                                                campaignName: "testCampaign",
                                                renderAsTestMessage: false,
                                                triggerType: .onAnalyticsEvent,
                                                titleText: normalMessageTitle,
                                                bodyText: normalMessageBody,
                                                textColor: UIColor.black,
                                                portraitImageData: portraitImageData,
                                                landscapeImageData: nil,
                                                backgroundColor: UIColor.white,
                                                primaryActionButton: defaultActionButton,
                                                primaryActionURL: URL(string: "http://google.com")!,
                                                secondaryActionButton: nil,
                                                secondaryActionURL: nil)
    
    displayImpl.displayMessage(cardMessage, displayDelegate: self)
  }
  
  @IBAction func showHugeImage(_ sender: Any) {
    let portraitImageRawData = produceImageOfSize(size: CGSize(width: 3000, height: 2000))
    let portraitImageData = InAppMessagingImageData(imageURL: "url not important", imageData: portraitImageRawData!)
    
    let cardMessage = InAppMessagingCardDisplay(messageID: "testID",
                                                campaignName: "testCampaign",
                                                renderAsTestMessage: false,
                                                triggerType: .onAnalyticsEvent,
                                                titleText: normalMessageTitle,
                                                bodyText: normalMessageBody,
                                                textColor: UIColor.black,
                                                portraitImageData: portraitImageData,
                                                landscapeImageData: nil,
                                                backgroundColor: UIColor.white,
                                                primaryActionButton: defaultActionButton,
                                                primaryActionURL: URL(string: "http://google.com")!,
                                                secondaryActionButton: nil,
                                                secondaryActionURL: nil)
    
    displayImpl.displayMessage(cardMessage, displayDelegate: self)
  }
}
