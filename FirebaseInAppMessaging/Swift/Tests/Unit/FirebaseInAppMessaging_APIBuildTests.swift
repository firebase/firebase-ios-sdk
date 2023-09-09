// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import XCTest

import FirebaseInAppMessaging
import FirebaseInAppMessagingSwift

final class FirebaseInAppMessagingSwift_APIBuildTests: XCTestCase {
  func usage() throws {
    // MARK: - FirebaseInAppMessaging

    let inAppMessaging: FirebaseInAppMessaging.InAppMessaging = FirebaseInAppMessaging.InAppMessaging.inAppMessaging()

    let _: Bool = inAppMessaging.messageDisplaySuppressed
    inAppMessaging.messageDisplaySuppressed = true

    // TODO(ncooke3): This should probably be removed in favor of the one in
    // FirebaseCore?
    let _: Bool = inAppMessaging.automaticDataCollectionEnabled
    inAppMessaging.automaticDataCollectionEnabled = true

    let _: FirebaseInAppMessaging.InAppMessagingDisplay = inAppMessaging.messageDisplayComponent
//    inAppMessaging.messageDisplayComponent = InAppMessagingDisplay

    inAppMessaging.triggerEvent("eventName")

    let _: InAppMessagingDisplayDelegate? = inAppMessaging.delegate
    inAppMessaging.delegate = nil

    // TODO(ncooke3): Does it make sense for these params to be nullable?
    let nullableText: String? = nil
    let nullableURL: URL? = nil
    let action: FirebaseInAppMessaging.InAppMessagingAction = FirebaseInAppMessaging.InAppMessagingAction(actionText: nullableText, actionURL: nullableURL)
    let _: String? = action.actionText
    let _: URL? = action.actionURL


    let nonnullText: String = ""
    let nonnullColor: UIColor = .black
    let button: FirebaseInAppMessaging.InAppMessagingActionButton = FirebaseInAppMessaging.InAppMessagingActionButton.init(buttonText: nonnullText, buttonTextColor: nonnullColor, backgroundColor: nonnullColor)
    let _: String = button.buttonText
    let _: UIColor = button.buttonTextColor
    let _: UIColor = button.buttonBackgroundColor


    let nullableImageData: FirebaseInAppMessaging.InAppMessagingImageData? = nil
    let nullableDict: [AnyHashable : Any]? = nil
    let bannerDisplay: FirebaseInAppMessaging.InAppMessagingBannerDisplay = FirebaseInAppMessaging.InAppMessagingBannerDisplay(
      campaignName: nonnullText,
      titleText: nonnullText,
      bodyText: nullableText,
      textColor: nonnullColor,
      backgroundColor: nonnullColor,
      imageData: nullableImageData,
      actionURL: nullableURL,
      appData: nullableDict
    )
    let _: String = bannerDisplay.title
    let _: InAppMessagingImageData? = bannerDisplay.imageData
    let _: String? = bannerDisplay.bodyText
    let _: UIColor = bannerDisplay.displayBackgroundColor
    let _: UIColor = bannerDisplay.textColor
    let _: URL? = bannerDisplay.actionURL


    let campaignInfo: FirebaseInAppMessaging.InAppMessagingCampaignInfo! = nil
    let _: String = campaignInfo.messageID
    let _: String = campaignInfo.campaignName
    let _: Bool = campaignInfo.renderAsTestMessage

    let cardDisplay: FirebaseInAppMessaging.InAppMessagingCardDisplay! = nil
    let _:String = cardDisplay.title
    let _:String? = cardDisplay.body
    let _:UIColor = cardDisplay.textColor
    let _:FirebaseInAppMessaging.InAppMessagingImageData = cardDisplay.portraitImageData
    let _:FirebaseInAppMessaging.InAppMessagingImageData? = cardDisplay.landscapeImageData
    let _:UIColor = cardDisplay.displayBackgroundColor
    let _:FirebaseInAppMessaging.InAppMessagingActionButton = cardDisplay.primaryActionButton
    let _:URL? = cardDisplay.primaryActionURL
    let _:FirebaseInAppMessaging.InAppMessagingActionButton? = cardDisplay.secondaryActionButton
    let _:URL? = cardDisplay.secondaryActionURL

    FirebaseInAppMessaging.InAppMessagingCardDisplay(
      campaignName: <#T##String#>,
      titleText: <#T##String#>,
      bodyText: <#T##String?#>,
      textColor: <#T##UIColor#>,
      portraitImageData: <#T##InAppMessagingImageData#>,
      landscapeImageData: <#T##InAppMessagingImageData?#>,
      backgroundColor: <#T##UIColor#>,
      primaryActionButton: <#T##InAppMessagingActionButton#>,
      secondaryActionButton: <#T##InAppMessagingActionButton?#>,
      primaryActionURL: <#T##URL?#>,
      secondaryActionURL: <#T##URL?#>,
      appData: <#T##[AnyHashable : Any]?#>
    )

    FirebaseInAppMessaging.InAppMessagingCardDisplay(
      messageID: <#T##String#>,
      campaignName: <#T##String#>,
      renderAsTestMessage: <#T##Bool#>,
      messageType: <#T##FIRInAppMessagingDisplayMessageType#>,
      triggerType: <#T##FIRInAppMessagingDisplayTriggerType#>
    )

    // MARK: - FirebaseInAppMessagingSwift
  }
}
