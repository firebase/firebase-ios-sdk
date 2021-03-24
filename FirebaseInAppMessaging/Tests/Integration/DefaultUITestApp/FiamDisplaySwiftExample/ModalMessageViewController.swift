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

import UIKit

class ModalMessageViewController: CommonMessageTestVC {
  class TestableModalMessage: InAppMessagingModalDisplay {
    var writableCampaignInfo: InAppMessagingCampaignInfo
    var writableTitle: String
    var writableBody: String?
    var writableTextColor: UIColor
    var writableImageData: InAppMessagingImageData?
    var writableBackgroundColor: UIColor
    var writableActionButton: InAppMessagingActionButton?
    var writableActionURL: URL?
    var writableMessageType: FIRInAppMessagingDisplayMessageType
    var writableTriggerType: FIRInAppMessagingDisplayTriggerType

    override var campaignInfo: InAppMessagingCampaignInfo {
      return writableCampaignInfo
    }

    override var title: String {
      return writableTitle
    }

    override var bodyText: String? {
      return writableBody
    }

    override var textColor: UIColor {
      return writableTextColor
    }

    override var imageData: InAppMessagingImageData? {
      return writableImageData
    }

    override var displayBackgroundColor: UIColor {
      return writableBackgroundColor
    }

    override var actionButton: InAppMessagingActionButton? {
      return writableActionButton
    }

    override var actionURL: URL? {
      return writableActionURL
    }

    override var type: FIRInAppMessagingDisplayMessageType {
      return writableMessageType
    }

    override var triggerType: FIRInAppMessagingDisplayTriggerType {
      return writableTriggerType
    }

    init(titleText: String,
         bodyText: String?,
         textColor: UIColor,
         backgroundColor: UIColor,
         imageData: InAppMessagingImageData?,
         actionButton: InAppMessagingActionButton?,
         actionURL: URL?) {
      writableTitle = titleText
      writableBody = bodyText
      writableTextColor = textColor
      writableImageData = imageData
      writableBackgroundColor = backgroundColor
      writableActionButton = actionButton
      writableActionURL = actionURL
      writableCampaignInfo = TestableCampaignInfo(messageID: "testID",
                                                  campaignName: "testCampaign",
                                                  isTestMessage: false)
      writableMessageType = FIRInAppMessagingDisplayMessageType.card
      writableTriggerType = FIRInAppMessagingDisplayTriggerType.onAnalyticsEvent
      super.init(messageID: "testID",
                 campaignName: "testCampaign",
                 renderAsTestMessage: false,
                 messageType: .imageOnly,
                 triggerType: .onAnalyticsEvent)
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

  @IBAction func showRegular(_ sender: Any) {
    verifyLabel.text = "Verification Label"
    let imageRawData = produceImageOfSize(size: CGSize(width: 200, height: 200))
    let fiamImageData = InAppMessagingImageData(imageURL: "url not important",
                                                imageData: imageRawData!)

    let modalMessage = TestableModalMessage(
      titleText: normalMessageTitle,
      bodyText: normalMessageBody,
      textColor: UIColor.black,
      backgroundColor: UIColor.blue,
      imageData: fiamImageData,
      actionButton: defaultActionButton,
      actionURL: URL(string: "http://firebase.com")
    )

    displayImpl.displayMessage(modalMessage, displayDelegate: self)
  }

  @IBAction func showWithoutImage(_ sender: Any) {
    verifyLabel.text = "Verification Label"
    let modalMessage = TestableModalMessage(
      titleText: normalMessageTitle,
      bodyText: normalMessageBody,
      textColor: UIColor.black,
      backgroundColor: UIColor.blue,
      imageData: nil,
      actionButton: defaultActionButton,
      actionURL: URL(string: "http://firebase.com")
    )

    displayImpl.displayMessage(modalMessage, displayDelegate: self)
  }

  @IBAction func showWithoutButton(_ sender: Any) {
    verifyLabel.text = "Verification Label"
    let imageRawData = produceImageOfSize(size: CGSize(width: 200, height: 200))
    let fiamImageData = InAppMessagingImageData(imageURL: "url not important",
                                                imageData: imageRawData!)

    let modalMessage = TestableModalMessage(
      titleText: normalMessageTitle,
      bodyText: normalMessageBody,
      textColor: UIColor.black,
      backgroundColor: UIColor.blue,
      imageData: fiamImageData,
      actionButton: nil,
      actionURL: nil
    )

    displayImpl.displayMessage(modalMessage, displayDelegate: self)
  }

  @IBAction func showWithoutImageAndButton(_ sender: Any) {
    verifyLabel.text = "Verification Label"
    let modalMessage = TestableModalMessage(
      titleText: normalMessageTitle,
      bodyText: normalMessageBody,
      textColor: UIColor.black,
      backgroundColor: UIColor.blue,
      imageData: nil,
      actionButton: nil,
      actionURL: nil
    )

    displayImpl.displayMessage(modalMessage, displayDelegate: self)
  }

  @IBAction func showWithLargeBody(_ sender: Any) {
    verifyLabel.text = "Verification Label"
    let modalMessage = TestableModalMessage(
      titleText: normalMessageTitle,
      bodyText: longBodyText,
      textColor: UIColor.black,
      backgroundColor: UIColor.blue,
      imageData: nil,
      actionButton: defaultActionButton,
      actionURL: URL(string: "http://firebase.com")
    )

    displayImpl.displayMessage(modalMessage, displayDelegate: self)
  }

  @IBAction func showWithLargeTitleAndBody(_ sender: Any) {
    verifyLabel.text = "Verification Label"
    let imageRawData = produceImageOfSize(size: CGSize(width: 200, height: 200))
    let fiamImageData = InAppMessagingImageData(imageURL: "url not important",
                                                imageData: imageRawData!)

    let modalMessage = TestableModalMessage(
      titleText: longTitleText,
      bodyText: longBodyText,
      textColor: UIColor.black,
      backgroundColor: UIColor.blue,
      imageData: fiamImageData,
      actionButton: defaultActionButton,
      actionURL: URL(string: "http://firebase.com")
    )

    displayImpl.displayMessage(modalMessage, displayDelegate: self)
  }

  @IBAction func showWithLargeTitle(_ sender: Any) {
    verifyLabel.text = "Verification Label"
    let modalMessage = TestableModalMessage(
      titleText: longBodyText,
      bodyText: normalMessageBody,
      textColor: UIColor.black,
      backgroundColor: UIColor.blue,
      imageData: nil,
      actionButton: defaultActionButton,
      actionURL: URL(string: "http://firebase.com")
    )

    displayImpl.displayMessage(modalMessage, displayDelegate: self)
  }

  @IBAction func showWithLargeTitleAndBodyWithoutImage(_ sender: Any) {
    verifyLabel.text = "Verification Label"
    let modalMessage = TestableModalMessage(
      titleText: longTitleText,
      bodyText: longBodyText,
      textColor: UIColor.black,
      backgroundColor: UIColor.blue,
      imageData: nil,
      actionButton: defaultActionButton,
      actionURL: URL(string: "http://firebase.com")
    )

    displayImpl.displayMessage(modalMessage, displayDelegate: self)
  }

  @IBAction func showWithLargeTitleWithoutBodyWithoutImageWithoutButton(_ sender: Any) {
    verifyLabel.text = "Verification Label"
    let modalMessage = TestableModalMessage(
      titleText: longBodyText,
      bodyText: "",
      textColor: UIColor.black,
      backgroundColor: UIColor.blue,
      imageData: nil,
      actionButton: nil,
      actionURL: nil
    )

    displayImpl.displayMessage(modalMessage, displayDelegate: self)
  }

  @IBAction func showWithWideImage(_ sender: Any) {
    verifyLabel.text = "Verification Label"
    let imageRawData = produceImageOfSize(size: CGSize(width: 600, height: 200))
    let fiamImageData = InAppMessagingImageData(imageURL: "url not important",
                                                imageData: imageRawData!)

    let modalMessage = TestableModalMessage(
      titleText: normalMessageTitle,
      bodyText: normalMessageBody,
      textColor: UIColor.black,
      backgroundColor: UIColor.blue,
      imageData: fiamImageData,
      actionButton: defaultActionButton,
      actionURL: URL(string: "http://firebase.com")
    )

    displayImpl.displayMessage(modalMessage, displayDelegate: self)
  }

  @IBAction func showWithThinImage(_ sender: Any) {
    verifyLabel.text = "Verification Label"
    let imageRawData = produceImageOfSize(size: CGSize(width: 200, height: 600))
    let fiamImageData = InAppMessagingImageData(imageURL: "url not important",
                                                imageData: imageRawData!)

    let modalMessage = TestableModalMessage(
      titleText: normalMessageTitle,
      bodyText: normalMessageBody,
      textColor: UIColor.black,
      backgroundColor: UIColor.blue,
      imageData: fiamImageData,
      actionButton: defaultActionButton,
      actionURL: URL(string: "http://firebase.com")
    )

    displayImpl.displayMessage(modalMessage, displayDelegate: self)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    // Do any additional setup after loading the view.
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
}
