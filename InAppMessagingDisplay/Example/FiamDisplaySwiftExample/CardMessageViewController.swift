/*
 * Copyright 2019 Google
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
                                                textColor: UIColor.black,
                                                portraitImageData: portraitImageData,
                                                backgroundColor: UIColor.white,
                                                primaryActionButton: defaultActionButton,
                                                primaryActionURL: URL(string: "http://google.com")!)
    cardMessage.body = normalMessageBody
    cardMessage.landscapeImageData = landscapeImageData

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
                                                textColor: UIColor.black,
                                                portraitImageData: portraitImageData,
                                                backgroundColor: UIColor.white,
                                                primaryActionButton: defaultActionButton,
                                                primaryActionURL: URL(string: "http://google.com")!)
    cardMessage.body = normalMessageBody

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
                                                textColor: UIColor.black,
                                                portraitImageData: portraitImageData,
                                                backgroundColor: UIColor.white,
                                                primaryActionButton: defaultActionButton,
                                                primaryActionURL: URL(string: "http://google.com")!)
    cardMessage.body = normalMessageBody
    cardMessage.landscapeImageData = landscapeImageData
    cardMessage.secondaryActionButton = defaultSecondaryActionButton

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
                                                textColor: UIColor.black,
                                                portraitImageData: portraitImageData,
                                                backgroundColor: UIColor.white,
                                                primaryActionButton: defaultActionButton,
                                                primaryActionURL: URL(string: "http://google.com")!)
    cardMessage.body = normalMessageBody
    cardMessage.secondaryActionButton = defaultSecondaryActionButton
    
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
                                                textColor: UIColor.black,
                                                portraitImageData: portraitImageData,
                                                backgroundColor: UIColor.white,
                                                primaryActionButton: defaultActionButton,
                                                primaryActionURL: URL(string: "http://google.com")!)
    cardMessage.body = longBodyText
    cardMessage.secondaryActionButton = defaultSecondaryActionButton

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
                                                textColor: UIColor.black,
                                                portraitImageData: portraitImageData,
                                                backgroundColor: UIColor.white,
                                                primaryActionButton: defaultActionButton,
                                                primaryActionURL: URL(string: "http://google.com")!)
    cardMessage.secondaryActionButton = defaultSecondaryActionButton

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
                                                textColor: UIColor.black,
                                                portraitImageData: portraitImageData,
                                                backgroundColor: UIColor.white,
                                                primaryActionButton: longTextButton,
                                                primaryActionURL: URL(string: "http://google.com")!)
    cardMessage.body = normalMessageBody
    cardMessage.secondaryActionButton = defaultSecondaryActionButton

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
                                                textColor: UIColor.black,
                                                portraitImageData: portraitImageData,
                                                backgroundColor: UIColor.white,
                                                primaryActionButton: defaultActionButton,
                                                primaryActionURL: URL(string: "http://google.com")!)
    cardMessage.body = normalMessageBody
    cardMessage.secondaryActionButton = longTextButton

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
                                                textColor: UIColor.black,
                                                portraitImageData: portraitImageData,
                                                backgroundColor: UIColor.white,
                                                primaryActionButton: defaultActionButton,
                                                primaryActionURL: URL(string: "http://google.com")!)
    cardMessage.body = normalMessageBody

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
                                                textColor: UIColor.black,
                                                portraitImageData: portraitImageData,
                                                backgroundColor: UIColor.white,
                                                primaryActionButton: defaultActionButton,
                                                primaryActionURL: URL(string: "http://google.com")!)
    cardMessage.body = normalMessageBody

    displayImpl.displayMessage(cardMessage, displayDelegate: self)
  }
}
