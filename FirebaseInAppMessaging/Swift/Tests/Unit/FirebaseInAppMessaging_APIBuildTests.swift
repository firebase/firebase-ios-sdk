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
import SwiftUI

final class FirebaseInAppMessaging_APIBuildTests: XCTestCase {
  func throwError() throws {}

  func usage() throws {
    let inAppMessaging = FirebaseInAppMessaging.InAppMessaging.inAppMessaging()

    let _: String = InAppMessagingErrorDomain

    do {
      try throwError() // Call a throwing method to suppress warnings.
    } catch InAppMessagingDisplayRenderError.imageDataInvalid {
    } catch InAppMessagingDisplayRenderError.unspecifiedError {}

    let _: Bool = inAppMessaging.messageDisplaySuppressed
    inAppMessaging.messageDisplaySuppressed = true

    let _: Bool = inAppMessaging.automaticDataCollectionEnabled
    inAppMessaging.automaticDataCollectionEnabled = true

    let _: FirebaseInAppMessaging.InAppMessagingDisplay = inAppMessaging.messageDisplayComponent
    let displayConformer: FirebaseInAppMessaging.InAppMessagingDisplay! = nil
    inAppMessaging.messageDisplayComponent = displayConformer

    inAppMessaging.triggerEvent("eventName")

    let delegate: FirebaseInAppMessaging.InAppMessagingDisplayDelegate? = inAppMessaging.delegate
    inAppMessaging.delegate = nil

    let nullableText: String? = nil
    let nullableURL: URL? = nil
    let action = FirebaseInAppMessaging.InAppMessagingAction(
      actionText: nullableText,
      actionURL: nullableURL
    )
    let _: String? = action.actionText
    let _: URL? = action.actionURL

    let nonnullText = ""
    let nonnullColor: UIColor = .black
    let button = FirebaseInAppMessaging.InAppMessagingActionButton(
      buttonText: nonnullText,
      buttonTextColor: nonnullColor,
      backgroundColor: nonnullColor
    )
    let _: String = button.buttonText
    let _: UIColor = button.buttonTextColor
    let _: UIColor = button.buttonBackgroundColor

    _ = FirebaseInAppMessaging.InAppMessagingDisplayMessageType.RawValue()
    let messageType: FirebaseInAppMessaging.InAppMessagingDisplayMessageType! = nil
    switch messageType! {
    case .modal: break
    case .banner: break
    case .imageOnly: break
    case .card: break
    @unknown default: break
    }

    _ = FirebaseInAppMessaging.InAppMessagingDismissType.RawValue()
    let dismissType: FirebaseInAppMessaging.InAppMessagingDismissType! = nil
    switch dismissType! {
    case .typeUserSwipe: break
    case .typeUserTapClose: break
    case .typeAuto: break
    case .unspecified: break
    @unknown default: break
    }

    _ = FirebaseInAppMessaging.InAppMessagingDisplayTriggerType.RawValue()
    let triggerType: FirebaseInAppMessaging.InAppMessagingDisplayTriggerType! = nil
    switch triggerType! {
    case .onAppForeground: break
    case .onAnalyticsEvent: break
    @unknown default: break
    }

    let nullableImageData: FirebaseInAppMessaging.InAppMessagingImageData? = nil
    let nullableDict: [AnyHashable: Any]? = nil
    let bannerDisplay = FirebaseInAppMessaging.InAppMessagingBannerDisplay(
      campaignName: nonnullText,
      titleText: nonnullText,
      bodyText: nullableText,
      textColor: nonnullColor,
      backgroundColor: nonnullColor,
      imageData: nullableImageData,
      actionURL: nullableURL,
      appData: nullableDict
    )
    _ = bannerDisplay as FirebaseInAppMessaging.InAppMessagingDisplayMessage
    let _: String = bannerDisplay.title
    let _: FirebaseInAppMessaging.InAppMessagingImageData? = bannerDisplay.imageData
    let _: String? = bannerDisplay.bodyText
    let _: UIColor = bannerDisplay.displayBackgroundColor
    let _: UIColor = bannerDisplay.textColor
    let _: URL? = bannerDisplay.actionURL

    let campaignInfo: FirebaseInAppMessaging.InAppMessagingCampaignInfo! = nil
    let _: String = campaignInfo.messageID
    let _: String = campaignInfo.campaignName
    let _: Bool = campaignInfo.renderAsTestMessage

    let nonnullImageData = FirebaseInAppMessaging.InAppMessagingImageData(
      imageURL: nonnullText,
      imageData: Data()
    )
    let _: Data? = nonnullImageData.imageRawData
    let _: String = nonnullImageData.imageURL

    let nullableActionButton: FirebaseInAppMessaging.InAppMessagingActionButton? = nil
    let cardDisplay = FirebaseInAppMessaging.InAppMessagingCardDisplay(
      campaignName: nonnullText,
      titleText: nonnullText,
      bodyText: nullableText,
      textColor: nonnullColor,
      portraitImageData: nonnullImageData,
      landscapeImageData: nullableImageData,
      backgroundColor: nonnullColor,
      primaryActionButton: button,
      secondaryActionButton: nullableActionButton,
      primaryActionURL: nullableURL,
      secondaryActionURL: nullableURL,
      appData: nullableDict
    )
    _ = cardDisplay as FirebaseInAppMessaging.InAppMessagingDisplayMessage
    let _: String = cardDisplay.title
    let _: String? = cardDisplay.body
    let _: UIColor = cardDisplay.textColor
    let _: FirebaseInAppMessaging.InAppMessagingImageData = cardDisplay.portraitImageData
    let _: FirebaseInAppMessaging.InAppMessagingImageData? = cardDisplay.landscapeImageData
    let _: UIColor = cardDisplay.displayBackgroundColor
    let _: FirebaseInAppMessaging.InAppMessagingActionButton = cardDisplay.primaryActionButton
    let _: URL? = cardDisplay.primaryActionURL
    let _: FirebaseInAppMessaging.InAppMessagingActionButton? = cardDisplay.secondaryActionButton
    let _: URL? = cardDisplay.secondaryActionURL

    let displayMessage = FirebaseInAppMessaging.InAppMessagingDisplayMessage(
      messageID: nonnullText,
      campaignName: nonnullText,
      renderAsTestMessage: true,
      messageType: messageType,
      triggerType: triggerType
    )
    let _: FirebaseInAppMessaging.InAppMessagingCampaignInfo = displayMessage.campaignInfo
    let _: FirebaseInAppMessaging.InAppMessagingDisplayMessageType = displayMessage.type
    let _: FirebaseInAppMessaging.InAppMessagingDisplayTriggerType = displayMessage.triggerType
    let _: [AnyHashable: Any]? = displayMessage.appData

    let imageOnlyDisplay = FirebaseInAppMessaging.InAppMessagingImageOnlyDisplay(
      campaignName: nonnullText,
      imageData: nonnullImageData,
      actionURL: nullableURL,
      appData: nullableDict
    )
    _ = imageOnlyDisplay as FirebaseInAppMessaging.InAppMessagingDisplayMessage
    let _: FirebaseInAppMessaging.InAppMessagingImageData = imageOnlyDisplay.imageData
    let _: URL? = imageOnlyDisplay.actionURL

    let modalDisplay = FirebaseInAppMessaging.InAppMessagingModalDisplay(
      campaignName: nonnullText,
      titleText: nonnullText,
      bodyText: nullableText,
      textColor: nonnullColor,
      backgroundColor: nonnullColor,
      imageData: nullableImageData,
      actionButton: nullableActionButton,
      actionURL: nullableURL,
      appData: nullableDict
    )
    _ = modalDisplay as FirebaseInAppMessaging.InAppMessagingDisplayMessage
    let _: String = modalDisplay.title
    let _: InAppMessagingImageData? = modalDisplay.imageData
    let _: String? = modalDisplay.bodyText
    let _: InAppMessagingActionButton? = modalDisplay.actionButton
    let _: URL? = modalDisplay.actionURL
    let _: UIColor = modalDisplay.displayBackgroundColor
    let _: UIColor = modalDisplay.textColor

    let display: FirebaseInAppMessaging.InAppMessagingDisplay! = nil
    display.displayMessage(displayMessage, displayDelegate: delegate!)

    if #available(iOS 13, tvOS 13, *) {
      let nullableImage: UIImage? = nil
      let nullableColor: UIColor? = nil
      let nullableAppData: [String: String]? = nil
      let _: FirebaseInAppMessaging.InAppMessagingCardDisplay = FirebaseInAppMessaging
        .InAppMessagingPreviewHelpers.cardMessage(
          campaignName: nonnullText,
          title: nonnullText,
          body: nullableText,
          textColor: nonnullColor,
          backgroundColor: nonnullColor,
          portraitImage: UIImage(),
          landscapeImage: nullableImage,
          primaryButtonText: nonnullText,
          primaryButtonTextColor: nonnullColor,
          primaryButtonBackgroundColor: nonnullColor,
          primaryActionURL: nullableURL,
          secondaryButtonText: nullableText,
          secondaryButtonTextColor: nullableColor,
          secondaryButtonBackgroundColor: nullableColor,
          secondaryActionURL: nullableURL,
          appData: nullableAppData
        )

      let _: FirebaseInAppMessaging.InAppMessagingModalDisplay = FirebaseInAppMessaging
        .InAppMessagingPreviewHelpers.modalMessage()
      let _: FirebaseInAppMessaging.InAppMessagingModalDisplay = FirebaseInAppMessaging
        .InAppMessagingPreviewHelpers.modalMessage(
          campaignName: nonnullText,
          title: nonnullText,
          body: nullableText,
          textColor: nonnullColor,
          backgroundColor: nonnullColor,
          image: nullableImage,
          buttonText: nullableText,
          buttonTextColor: nullableColor,
          buttonBackgroundColor: nullableColor,
          actionURL: nullableURL,
          appData: nullableAppData
        )

      let _: FirebaseInAppMessaging.InAppMessagingBannerDisplay = FirebaseInAppMessaging
        .InAppMessagingPreviewHelpers.bannerMessage()
      let _: FirebaseInAppMessaging.InAppMessagingBannerDisplay = FirebaseInAppMessaging
        .InAppMessagingPreviewHelpers.bannerMessage(
          campaignName: nonnullText,
          title: nonnullText,
          body: nullableText,
          textColor: nonnullColor,
          backgroundColor: nonnullColor,
          image: nullableImage,
          actionURL: nullableURL,
          appData: nullableAppData
        )

      let _: FirebaseInAppMessaging.InAppMessagingImageOnlyDisplay = FirebaseInAppMessaging
        .InAppMessagingPreviewHelpers.imageOnlyMessage(image: UIImage())
      let _: FirebaseInAppMessaging.InAppMessagingImageOnlyDisplay = FirebaseInAppMessaging
        .InAppMessagingPreviewHelpers.imageOnlyMessage(
          campaignName: nonnullText,
          image: UIImage(),
          actionURL: nullableURL,
          appData: nullableAppData
        )

      let swiftDelegate = FirebaseInAppMessaging.InAppMessagingPreviewHelpers.Delegate()
      _ = swiftDelegate as InAppMessagingDisplayDelegate
    }

    @available(iOS 13, tvOS 13, *)
    struct MyView: View {
      var body: some View {
        Text("Hello, world!")
          .imageOnlyInAppMessage(
            closure: { (_: FirebaseInAppMessaging.InAppMessagingImageOnlyDisplay,
                        _: FirebaseInAppMessaging.InAppMessagingDisplayDelegate) in
                Text("My image-only display!")
            }
          )
        Text("Hello, world!")
          .bannerInAppMessage(closure: { (_: FirebaseInAppMessaging.InAppMessagingBannerDisplay,
                                          _: FirebaseInAppMessaging.InAppMessagingDisplayDelegate) in
              Text("My banner!")
            })
        Text("Hello, world!")
          .modalInAppMessage(closure: { (_: FirebaseInAppMessaging.InAppMessagingModalDisplay,
                                         _: FirebaseInAppMessaging.InAppMessagingDisplayDelegate) in
              Text("My modal!")
            })
        Text("Hello, world!")
          .cardInAppMessage(closure: { (_: FirebaseInAppMessaging.InAppMessagingCardDisplay,
                                        _: FirebaseInAppMessaging.InAppMessagingDisplayDelegate) in
              Text("My card!")
            })
      }
    }
  }
}
