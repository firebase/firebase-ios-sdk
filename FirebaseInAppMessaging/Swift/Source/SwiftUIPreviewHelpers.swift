//
//  SwiftUIPreviewHelpers.swift
//  FirebaseInAppMessagingSwift
//
//  Created by Chris Tibbs on 6/24/21.
//

import FirebaseInAppMessaging

struct InAppMessagingPreviewHelpers {
  static func cardMessage(campaignName: String = "Card message campaign",
                          title: String = "Title for modal message",
                          body: String? = "Body for modal message",
                          textColor: UIColor = UIColor.label,
                          backgroundColor: UIColor = UIColor.systemBackground,
                          portraitImage: UIImage = UIImage(systemName: "message")!,
                          landscapeImage: UIImage? = UIImage(systemName: "message.fill"),
                          primaryButtonText: String = "Click me!",
                          primaryButtonTextColor: UIColor = UIColor.systemBlue,
                          primaryButtonBackgroundColor: UIColor = UIColor.secondarySystemBackground,
                          primaryActionURL: URL? = nil,
                          secondaryButtonText: String? = "Dismiss",
                          secondaryButtonTextColor: UIColor? = UIColor.secondaryLabel,
                          secondaryButtonBackgroundColor: UIColor? = UIColor
                            .tertiarySystemBackground,
                          secondaryActionURL: URL? = nil,
                          appData: [String: String]? = nil) -> InAppMessagingCardDisplay {
    // This may crash the preview if an invalid portrait image is provided, card messages must have
    // a valid portrait image.
    let portraitImageData = InAppMessagingImageData(imageURL: "http://fakeurl.com",
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

  static func modalMessage(campaignName: String = "Modal message campaign",
                           title: String = "Title for modal message",
                           body: String? = "Body for modal message",
                           textColor: UIColor = UIColor.black,
                           backgroundColor: UIColor = UIColor.white,
                           image: UIImage? = UIImage(systemName: "message"),
                           buttonText: String? = "Click me!",
                           buttonTextColor: UIColor? = UIColor.systemBlue,
                           buttonBackgroundColor: UIColor? = UIColor
                             .white,
                           actionURL: URL? = nil,
                           appData: [String: String]? = nil) -> InAppMessagingModalDisplay {
    var imageData: InAppMessagingImageData?
    if let data = image?.pngData() {
      imageData = InAppMessagingImageData(imageURL: "http://fakeurl.com", imageData: data)
    }

    var actionButton: InAppMessagingActionButton?
    if let buttonText = buttonText,
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

  static func bannerMessage(campaignName: String = "Banner message campaign",
                            title: String = "Title for banner message",
                            body: String? = "Body for banner message",
                            textColor: UIColor = UIColor.black,
                            backgroundColor: UIColor = UIColor.white,
                            image: UIImage? = UIImage(systemName: "message"),
                            actionURL: URL? = nil,
                            appData: [String: String]? = nil) -> InAppMessagingBannerDisplay {
    var imageData: InAppMessagingImageData?
    if let data = image?.pngData() {
      imageData = InAppMessagingImageData(imageURL: "http://fakeurl.com", imageData: data)
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

  static func imageOnlyMessage(campaignName: String = "Image-only message campaign",
                               image: UIImage,
                               actionURL: URL? = nil,
                               appData: [String: String]? = nil)
    -> InAppMessagingImageOnlyDisplay {
    // This may crash the preview if an invalid image is provided, image-only messages must have a
    // valid portrait image.
    let imageData = InAppMessagingImageData(imageURL: "http://fakeurl.com",
                                            imageData: image.pngData()!)
    return InAppMessagingImageOnlyDisplay(
      campaignName: campaignName,
      imageData: imageData,
      actionURL: actionURL,
      appData: appData
    )
  }
}
