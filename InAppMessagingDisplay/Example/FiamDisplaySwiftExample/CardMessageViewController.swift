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

  @IBAction func showRegularOneButtonWithBothImages(_ sender: Any) {
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
                                                portraitImageData: portraitImageData,
                                                landscapeImageData: landscapeImageData,
                                                backgroundColor: UIColor.white,
                                                primaryActionButton: defaultActionButton,
                                                primaryActionURL: URL(string: "http://google.com")!,
                                                secondaryActionButton: defaultSecondaryActionButton,
                                                secondaryActionURL: nil)
    
    displayImpl.displayMessage(cardMessage, displayDelegate: self)
  }
  
  @IBAction func showRegularTwoButtonWithOnlyPortrait(_ sender: Any) {
    let portraitImageRawData = produceImageOfSize(size: CGSize(width: 300, height: 200))
    let portraitImageData = InAppMessagingImageData(imageURL: "url not important", imageData: portraitImageRawData!)
    
    let cardMessage = InAppMessagingCardDisplay(messageID: "testID",
                                                campaignName: "testCampaign",
                                                renderAsTestMessage: false,
                                                triggerType: .onAnalyticsEvent,
                                                titleText: normalMessageTitle,
                                                bodyText: normalMessageBody,
                                                portraitImageData: portraitImageData,
                                                landscapeImageData: nil,
                                                backgroundColor: UIColor.white,
                                                primaryActionButton: defaultActionButton,
                                                primaryActionURL: URL(string: "http://google.com")!,
                                                secondaryActionButton: defaultSecondaryActionButton,
                                                secondaryActionURL: nil)
    
    displayImpl.displayMessage(cardMessage, displayDelegate: self)
  }
}
