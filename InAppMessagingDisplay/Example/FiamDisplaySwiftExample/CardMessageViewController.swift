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

  @IBAction func showRegular(_ sender: Any) {
    let portraitImageRawData = produceImageOfSize(size: CGSize(width: 200, height: 200))
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
}
