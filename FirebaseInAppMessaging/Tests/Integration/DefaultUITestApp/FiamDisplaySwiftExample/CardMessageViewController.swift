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
  func testCardMessage(titleText: String, body: String?, textColor: UIColor,
                       portraitImageData: InAppMessagingImageData,
                       landscapeImageData: InAppMessagingImageData?, backgroundColor: UIColor,
                       primaryActionButton: InAppMessagingActionButton, primaryActionURL: URL?,
                       secondaryActionButton: InAppMessagingActionButton?,
                       secondaryActionURL: URL?) -> InAppMessagingCardDisplay {
    return InAppMessagingCardDisplay(
      campaignName: "campaignName",
      titleText: titleText,
      bodyText: body,
      textColor: textColor,
      portraitImageData: portraitImageData,
      landscapeImageData: landscapeImageData,
      backgroundColor: backgroundColor,
      primaryActionButton: primaryActionButton,
      secondaryActionButton: secondaryActionButton,
      primaryActionURL: primaryActionURL,
      secondaryActionURL: secondaryActionURL,
      appData: nil
    )
  }

  let displayImpl = InAppMessagingDefaultDisplayImpl()

  @IBOutlet var verifyLabel: UILabel!

  override func messageClicked(_ inAppMessage: InAppMessagingDisplayMessage,
                               with action: InAppMessagingAction) {
    super.messageClicked(inAppMessage, with: action)
    verifyLabel.text = "message clicked!"
  }

  override func messageDismissed(_ inAppMessage: InAppMessagingDisplayMessage,
                                 dismissType: InAppMessagingDismissType) {
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

    let cardMessage = testCardMessage(
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

    let cardMessage = testCardMessage(
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

    let cardMessage = testCardMessage(
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

    let cardMessage = testCardMessage(
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

    let cardMessage = testCardMessage(
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

    let cardMessage = testCardMessage(
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

    let cardMessage = testCardMessage(
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

    let cardMessage = testCardMessage(
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

    let cardMessage = testCardMessage(
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

    let cardMessage = testCardMessage(
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
