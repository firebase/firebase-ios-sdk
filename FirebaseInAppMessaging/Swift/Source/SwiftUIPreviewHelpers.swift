// Copyright 2021 Google LLC
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

import UIKit

#if SWIFT_PACKAGE
  @_exported import FirebaseInAppMessagingInternal
#endif // SWIFT_PACKAGE

@available(iOS 13.0, tvOS 13.0, *)
@available(iOSApplicationExtension, unavailable)
@available(tvOSApplicationExtension, unavailable)
public enum InAppMessagingPreviewHelpers {
  public static func cardMessage(campaignName: String = "Card message campaign",
                                 title: String = "Title for modal message",
                                 body: String? = "Body for modal message",
                                 textColor: UIColor = UIColor.label,
                                 backgroundColor: UIColor = UIColor.black,
                                 portraitImage: UIImage = UIImage(systemName: "rectangle")!,
                                 landscapeImage: UIImage? = UIImage(systemName: "square"),
                                 primaryButtonText: String = "Click me!",
                                 primaryButtonTextColor: UIColor = UIColor.systemBlue,
                                 primaryButtonBackgroundColor: UIColor = UIColor.systemGray,
                                 primaryActionURL: URL? = nil,
                                 secondaryButtonText: String? = "Dismiss",
                                 secondaryButtonTextColor: UIColor? = UIColor.secondaryLabel,
                                 secondaryButtonBackgroundColor: UIColor? = UIColor.systemYellow,
                                 secondaryActionURL: URL? = nil,
                                 appData: [String: String]? = nil) -> InAppMessagingCardDisplay {
    // This may crash the preview if an invalid portrait image is provided, card messages must have
    // a valid portrait image.
    let portraitImageData = InAppMessagingImageData(imageURL: "https://firebase.google.com/",
                                                    imageData: portraitImage.pngData()!)
    var landscapeImageData: InAppMessagingImageData?
    if let landscapeData = landscapeImage?.pngData() {
      landscapeImageData = InAppMessagingImageData(
        imageURL: "http://fakeurl.com",
        imageData: landscapeData
      )
    }

    let primaryActionButton = InAppMessagingActionButton(buttonText: primaryButtonText,
                                                         buttonTextColor: primaryButtonTextColor,
                                                         backgroundColor: primaryButtonBackgroundColor)

    var secondaryActionButton: InAppMessagingActionButton?
    if secondaryButtonText != nil,
       secondaryButtonTextColor != nil,
       secondaryButtonBackgroundColor != nil {
      secondaryActionButton = InAppMessagingActionButton(buttonText: secondaryButtonText!,
                                                         buttonTextColor: secondaryButtonTextColor!,
                                                         backgroundColor: secondaryButtonBackgroundColor!)
    }
    return InAppMessagingCardDisplay(
      campaignName: campaignName,
      titleText: title,
      bodyText: body,
      textColor: textColor,
      portraitImageData: portraitImageData,
      landscapeImageData: landscapeImageData,
      backgroundColor: backgroundColor,
      primaryActionButton: primaryActionButton,
      secondaryActionButton: secondaryActionButton,
      primaryActionURL: primaryActionURL,
      secondaryActionURL: secondaryActionURL,
      appData: appData
    )
  }

  public static func modalMessage(campaignName: String = "Modal message campaign",
                                  title: String = "Title for modal message",
                                  body: String? = "Body for modal message",
                                  textColor: UIColor = UIColor.black,
                                  backgroundColor: UIColor = UIColor.white,
                                  image: UIImage? = UIImage(systemName: "rectangle"),
                                  buttonText: String? = "Click me!",
                                  buttonTextColor: UIColor? = UIColor.systemBlue,
                                  buttonBackgroundColor: UIColor? = UIColor
                                    .white,
                                  actionURL: URL? = nil,
                                  appData: [String: String]? = nil) -> InAppMessagingModalDisplay {
    var imageData: InAppMessagingImageData?
    if let data = image?.pngData() {
      imageData = InAppMessagingImageData(imageURL: "https://firebase.google.com/", imageData: data)
    }

    var actionButton: InAppMessagingActionButton?
    if let buttonText,
       let buttonTextColor = buttonTextColor,
       let buttonBackgroundColor = buttonBackgroundColor {
      actionButton = InAppMessagingActionButton(buttonText: buttonText,
                                                buttonTextColor: buttonTextColor,
                                                backgroundColor: buttonBackgroundColor)
    }
    return InAppMessagingModalDisplay(
      campaignName: campaignName,
      titleText: title,
      bodyText: body,
      textColor: textColor,
      backgroundColor: backgroundColor,
      imageData: imageData,
      actionButton: actionButton,
      actionURL: actionURL,
      appData: appData
    )
  }

  public static func bannerMessage(campaignName: String = "Banner message campaign",
                                   title: String = "Title for banner message",
                                   body: String? = "Body for banner message",
                                   textColor: UIColor = UIColor.black,
                                   backgroundColor: UIColor = UIColor.white,
                                   image: UIImage? = UIImage(systemName: "square"),
                                   actionURL: URL? = nil,
                                   appData: [String: String]? = nil)
    -> InAppMessagingBannerDisplay {
    var imageData: InAppMessagingImageData?
    if let data = image?.pngData() {
      imageData = InAppMessagingImageData(imageURL: "https://firebase.google.com/", imageData: data)
    }
    return InAppMessagingBannerDisplay(
      campaignName: campaignName,
      titleText: title,
      bodyText: body,
      textColor: textColor,
      backgroundColor: backgroundColor,
      imageData: imageData,
      actionURL: actionURL,
      appData: appData
    )
  }

  public static func imageOnlyMessage(campaignName: String = "Image-only message campaign",
                                      image: UIImage,
                                      actionURL: URL? = nil,
                                      appData: [String: String]? = nil)
    -> InAppMessagingImageOnlyDisplay {
    // This may crash the preview if an invalid image is provided, image-only messages must have a
    // valid portrait image.
    let imageData = InAppMessagingImageData(imageURL: "https://firebase.google.com/",
                                            imageData: image.pngData()!)
    return InAppMessagingImageOnlyDisplay(
      campaignName: campaignName,
      imageData: imageData,
      actionURL: actionURL,
      appData: appData
    )
  }

  public class Delegate: NSObject, InAppMessagingDisplayDelegate {}
}
