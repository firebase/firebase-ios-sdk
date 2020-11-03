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
  class TestableCardMessage: InAppMessagingCardDisplay {
    var writableCampaignInfo: InAppMessagingCampaignInfo
    var writableTitle: String
    var writableBody: String?
    var writableTextColor: UIColor
    var writablePortraitImageData: InAppMessagingImageData
    var writableLandscapeImageData: InAppMessagingImageData?
    var writableBackgroundColor: UIColor
    var writablePrimaryActionButton: InAppMessagingActionButton
    var writablePrimaryActionURL: URL
    var writableSecondaryActionButton: InAppMessagingActionButton?
    var writableSecondaryActionURL: URL?
    var writableMessageType: FIRInAppMessagingDisplayMessageType
    var writableTriggerType: FIRInAppMessagingDisplayTriggerType

    override var campaignInfo: InAppMessagingCampaignInfo {
      return writableCampaignInfo
    }

    override var title: String {
      return writableTitle
    }

    override var body: String? {
      return writableBody
    }

    override var textColor: UIColor {
      return writableTextColor
    }

    override var portraitImageData: InAppMessagingImageData {
      return writablePortraitImageData
    }

    override var landscapeImageData: InAppMessagingImageData? {
      return writableLandscapeImageData
    }

    override var displayBackgroundColor: UIColor {
      return writableBackgroundColor
    }

    override var primaryActionButton: InAppMessagingActionButton {
      return writablePrimaryActionButton
    }

    override var primaryActionURL: URL {
      return writablePrimaryActionURL
    }

    override var secondaryActionButton: InAppMessagingActionButton? {
      return writableSecondaryActionButton
    }

    override var secondaryActionURL: URL? {
      return writableSecondaryActionURL
    }

    override var type: FIRInAppMessagingDisplayMessageType {
      return writableMessageType
    }

    override var triggerType: FIRInAppMessagingDisplayTriggerType {
      return writableTriggerType
    }

    init(titleText: String,
         body: String?,
         textColor: UIColor,
         portraitImageData: InAppMessagingImageData,
         landscapeImageData: InAppMessagingImageData?,
         backgroundColor: UIColor,
         primaryActionButton: InAppMessagingActionButton,
         primaryActionURL: URL,
         secondaryActionButton: InAppMessagingActionButton?,
         secondaryActionURL: URL?) {
      writableTitle = titleText
      writableBody = body
      writableTextColor = textColor
      writablePortraitImageData = portraitImageData
      writableLandscapeImageData = landscapeImageData
      writableBackgroundColor = backgroundColor
      writablePrimaryActionButton = primaryActionButton
      writablePrimaryActionURL = primaryActionURL
      writableSecondaryActionButton = secondaryActionButton
      writableSecondaryActionURL = secondaryActionURL
      writableCampaignInfo = TestableCampaignInfo(messageID: "testID",
                                                  campaignName: "testCampaign",
                                                  isTestMessage: false)
      writableMessageType = FIRInAppMessagingDisplayMessageType.card
      writableTriggerType = FIRInAppMessagingDisplayTriggerType.onAnalyticsEvent
    }
  }

  let displayImpl = InAppMessagingDefaultDisplayImpl()

  @IBOutlet var verifyLabel: UILabel!

  override func messageClicked(_ inAppMessage: InAppMessagingDisplayMessage,
                               with action: InAppMessagingAction) {
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
    let portraitImageData = InAppMessagingImageData(imageURL: "url not important",
                                                    imageData: portraitImageRawData!)

    let landscapeImageRawData = produceImageOfSize(size: CGSize(width: 200, height: 200))
    let landscapeImageData = InAppMessagingImageData(imageURL: "url not important",
                                                     imageData: landscapeImageRawData!)

    let cardMessage = TestableCardMessage(
      titleText: normalMessageTitle,
      body: normalMessageBody,
      textColor: UIColor.black,
      portraitImageData: portraitImageData,
      landscapeImageData: landscapeImageData,
      backgroundColor: UIColor.white,
      primaryActionButton: defaultActionButton,
      primaryActionURL: URL(string: "http://google.com")!,
      secondaryActionButton: nil,
      secondaryActionURL: nil
    )

    displayImpl.displayMessage(cardMessage, displayDelegate: self)
  }

  @IBAction func showRegularOneButtonWithOnlyPortrait(_ sender: Any) {
    let portraitImageRawData = produceImageOfSize(size: CGSize(width: 300, height: 200))
    let portraitImageData = InAppMessagingImageData(imageURL: "url not important",
                                                    imageData: portraitImageRawData!)

    let cardMessage = TestableCardMessage(
      titleText: normalMessageTitle,
      body: nil,
      textColor: UIColor.black,
      portraitImageData: portraitImageData,
      landscapeImageData: nil,
      backgroundColor: UIColor.white,
      primaryActionButton: defaultActionButton,
      primaryActionURL: URL(string: "http://google.com")!,
      secondaryActionButton: nil,
      secondaryActionURL: nil
    )

    displayImpl.displayMessage(cardMessage, displayDelegate: self)
  }

  @IBAction func showRegularTwoButtonWithBothImages(_ sender: Any) {
    let portraitImageRawData = produceImageOfSize(size: CGSize(width: 300, height: 200))
    let portraitImageData = InAppMessagingImageData(imageURL: "url not important",
                                                    imageData: portraitImageRawData!)

    let landscapeImageRawData = produceImageOfSize(size: CGSize(width: 300, height: 300))
    let landscapeImageData = InAppMessagingImageData(imageURL: "url not important",
                                                     imageData: landscapeImageRawData!)

    let cardMessage = TestableCardMessage(
      titleText: normalMessageTitle,
      body: normalMessageBody,
      textColor: UIColor.black,
      portraitImageData: portraitImageData,
      landscapeImageData: landscapeImageData,
      backgroundColor: UIColor.white,
      primaryActionButton: defaultActionButton,
      primaryActionURL: URL(string: "http://google.com")!,
      secondaryActionButton: defaultSecondaryActionButton,
      secondaryActionURL: nil
    )

    displayImpl.displayMessage(cardMessage, displayDelegate: self)
  }

  @IBAction func showLongTitleRegularBody(_ sender: Any) {
    let portraitImageRawData = produceImageOfSize(size: CGSize(width: 300, height: 200))
    let portraitImageData = InAppMessagingImageData(imageURL: "url not important",
                                                    imageData: portraitImageRawData!)

    let cardMessage = TestableCardMessage(
      titleText: longTitleText,
      body: normalMessageBody,
      textColor: UIColor.black,
      portraitImageData: portraitImageData,
      landscapeImageData: nil,
      backgroundColor: UIColor.white,
      primaryActionButton: defaultActionButton,
      primaryActionURL: URL(string: "http://google.com")!,
      secondaryActionButton: defaultSecondaryActionButton,
      secondaryActionURL: nil
    )

    displayImpl.displayMessage(cardMessage, displayDelegate: self)
  }

  @IBAction func showRegularTitleLongBody(_ sender: Any) {
    let portraitImageRawData = produceImageOfSize(size: CGSize(width: 300, height: 200))
    let portraitImageData = InAppMessagingImageData(imageURL: "url not important",
                                                    imageData: portraitImageRawData!)

    let cardMessage = TestableCardMessage(
      titleText: normalMessageTitle,
      body: longBodyText,
      textColor: UIColor.black,
      portraitImageData: portraitImageData,
      landscapeImageData: nil,
      backgroundColor: UIColor.white,
      primaryActionButton: defaultActionButton,
      primaryActionURL: URL(string: "http://google.com")!,
      secondaryActionButton: defaultSecondaryActionButton,
      secondaryActionURL: nil
    )

    displayImpl.displayMessage(cardMessage, displayDelegate: self)
  }

  @IBAction func showLongTitleNoBody(_ sender: Any) {
    let portraitImageRawData = produceImageOfSize(size: CGSize(width: 300, height: 200))
    let portraitImageData = InAppMessagingImageData(imageURL: "url not important",
                                                    imageData: portraitImageRawData!)

    let cardMessage = TestableCardMessage(
      titleText: longTitleText,
      body: nil,
      textColor: UIColor.black,
      portraitImageData: portraitImageData,
      landscapeImageData: nil,
      backgroundColor: UIColor.white,
      primaryActionButton: defaultActionButton,
      primaryActionURL: URL(string: "http://google.com")!,
      secondaryActionButton: defaultSecondaryActionButton,
      secondaryActionURL: nil
    )

    displayImpl.displayMessage(cardMessage, displayDelegate: self)
  }

  @IBAction func showLongPrimaryButton(_ sender: Any) {
    let portraitImageRawData = produceImageOfSize(size: CGSize(width: 300, height: 200))
    let portraitImageData = InAppMessagingImageData(imageURL: "url not important",
                                                    imageData: portraitImageRawData!)

    let cardMessage = TestableCardMessage(
      titleText: longTitleText,
      body: normalMessageBody,
      textColor: UIColor.black,
      portraitImageData: portraitImageData,
      landscapeImageData: nil,
      backgroundColor: UIColor.white,
      primaryActionButton: longTextButton,
      primaryActionURL: URL(string: "http://google.com")!,
      secondaryActionButton: defaultSecondaryActionButton,
      secondaryActionURL: nil
    )

    displayImpl.displayMessage(cardMessage, displayDelegate: self)
  }

  @IBAction func showLongSecondaryButton(_ sender: Any) {
    let portraitImageRawData = produceImageOfSize(size: CGSize(width: 300, height: 200))
    let portraitImageData = InAppMessagingImageData(imageURL: "url not important",
                                                    imageData: portraitImageRawData!)

    let cardMessage = TestableCardMessage(
      titleText: longTitleText,
      body: normalMessageBody,
      textColor: UIColor.black,
      portraitImageData: portraitImageData,
      landscapeImageData: nil,
      backgroundColor: UIColor.white,
      primaryActionButton: defaultActionButton,
      primaryActionURL: URL(string: "http://google.com")!,
      secondaryActionButton: longTextButton,
      secondaryActionURL: nil
    )

    displayImpl.displayMessage(cardMessage, displayDelegate: self)
  }

  @IBAction func showSmallImage(_ sender: Any) {
    let portraitImageRawData = produceImageOfSize(size: CGSize(width: 30, height: 20))
    let portraitImageData = InAppMessagingImageData(imageURL: "url not important",
                                                    imageData: portraitImageRawData!)

    let cardMessage = TestableCardMessage(
      titleText: normalMessageTitle,
      body: normalMessageBody,
      textColor: UIColor.black,
      portraitImageData: portraitImageData,
      landscapeImageData: nil,
      backgroundColor: UIColor.white,
      primaryActionButton: defaultActionButton,
      primaryActionURL: URL(string: "http://google.com")!,
      secondaryActionButton: nil,
      secondaryActionURL: nil
    )

    displayImpl.displayMessage(cardMessage, displayDelegate: self)
  }

  @IBAction func showHugeImage(_ sender: Any) {
    let portraitImageRawData = produceImageOfSize(size: CGSize(width: 3000, height: 2000))
    let portraitImageData = InAppMessagingImageData(imageURL: "url not important",
                                                    imageData: portraitImageRawData!)

    let cardMessage = TestableCardMessage(
      titleText: normalMessageTitle,
      body: normalMessageBody,
      textColor: UIColor.black,
      portraitImageData: portraitImageData,
      landscapeImageData: nil,
      backgroundColor: UIColor.white,
      primaryActionButton: defaultActionButton,
      primaryActionURL: URL(string: "http://google.com")!,
      secondaryActionButton: nil,
      secondaryActionURL: nil
    )

    displayImpl.displayMessage(cardMessage, displayDelegate: self)
  }
}
