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

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// The type and UI style of an in-app message.
typedef NS_ENUM(NSInteger, FIRInAppMessagingDisplayMessageType) {
  /// Modal style.
  FIRInAppMessagingDisplayMessageTypeModal,
  /// Banner style.
  FIRInAppMessagingDisplayMessageTypeBanner,
  /// Image-only style.
  FIRInAppMessagingDisplayMessageTypeImageOnly,
  /// Card style.
  FIRInAppMessagingDisplayMessageTypeCard
};

/// Represents how an in-app message should be triggered to appear.
typedef NS_ENUM(NSInteger, FIRInAppMessagingDisplayTriggerType) {
  /// Triggered on app foreground.
  FIRInAppMessagingDisplayTriggerTypeOnAppForeground,
  /// Triggered from an analytics event being fired.
  FIRInAppMessagingDisplayTriggerTypeOnAnalyticsEvent
};

/** Contains the display information for an action button.
 */
NS_SWIFT_NAME(InAppMessagingActionButton)
@interface FIRInAppMessagingActionButton : NSObject

/**
 * Gets the text string for the button
 */
@property(nonatomic, nonnull, copy, readonly) NSString *buttonText;

/**
 * Gets the button's text color.
 */
@property(nonatomic, copy, nonnull, readonly) UIColor *buttonTextColor;

/**
 * Gets the button's background color
 */
@property(nonatomic, copy, nonnull, readonly) UIColor *buttonBackgroundColor;

/// Unavailable.
- (instancetype)init NS_UNAVAILABLE;

/// Deprecated, this class shouldn't be directly instantiated.
- (instancetype)initWithButtonText:(NSString *)btnText
                   buttonTextColor:(UIColor *)textColor
                   backgroundColor:(UIColor *)bkgColor __deprecated;
@end

/** Contain display data for an image for a fiam message.
 */
NS_SWIFT_NAME(InAppMessagingImageData)
@interface FIRInAppMessagingImageData : NSObject

/**
 * Gets the image URL from image data.
 */
@property(nonatomic, nonnull, copy, readonly) NSString *imageURL;

/**
 * Gets the downloaded image data. It can be null if headless component fails to load it.
 */
@property(nonatomic, readonly, nullable) NSData *imageRawData;

/// Unavailable.
- (instancetype)init NS_UNAVAILABLE;

/// Deprecated, this class shouldn't be directly instantiated.
- (instancetype)initWithImageURL:(NSString *)imageURL imageData:(NSData *)imageData __deprecated;
@end

/** Defines the metadata for the campaign to which a FIAM message belongs.
 */
@interface FIRInAppMessagingCampaignInfo : NSObject

/**
 * Identifier for the campaign for this message.
 */
@property(nonatomic, nonnull, copy, readonly) NSString *messageID;

/**
 * The name of this campaign, as defined in the console on campaign creation.
 */
@property(nonatomic, nonnull, copy, readonly) NSString *campaignName;

/**
 * Whether or not this message is being rendered in Test On Device mode.
 */
@property(nonatomic, readonly) BOOL renderAsTestMessage;

/// Unavailable.
- (instancetype)init NS_UNAVAILABLE;

/// Deprecated, this class shouldn't be directly instantiated.
- (instancetype)initWithMessageID:(NSString *)messageID
                     campaignName:(NSString *)campaignName
              renderAsTestMessage:(BOOL)renderAsTestMessage __deprecated;

@end

/** Defines the metadata for a FIAM action.
 */
NS_SWIFT_NAME(InAppMessagingAction)
@interface FIRInAppMessagingAction : NSObject

/**
 * The text of the action button, if applicable.
 */
@property(nonatomic, nullable, copy, readonly) NSString *actionText;
/**
 * The URL to follow if the action is clicked.
 */
@property(nonatomic, nonnull, copy, readonly) NSURL *actionURL;

/// Unavailable.
- (instancetype)init NS_UNAVAILABLE;

/// Deprecated, this class shouldn't be directly instantiated.
- (instancetype)initWithActionText:(nullable NSString *)actionText actionURL:(NSURL *)actionURL;

@end

/**
 * Base class representing a FIAM message to be displayed. Don't create instance
 * of this class directly. Instantiate one of its subclasses instead.
 */
NS_SWIFT_NAME(InAppMessagingDisplayMessage)
@interface FIRInAppMessagingDisplayMessage : NSObject

/**
 * Metadata for the campaign to which this message belongs.
 */
@property(nonatomic, copy, nonnull, readonly) FIRInAppMessagingCampaignInfo *campaignInfo;

/**
 * The type and UI style of this message.
 */
@property(nonatomic, readonly) FIRInAppMessagingDisplayMessageType type;

/**
 * How this message should be triggered.
 */
@property(nonatomic, readonly) FIRInAppMessagingDisplayTriggerType triggerType;

/// Unavailable.
- (instancetype)init NS_UNAVAILABLE;

/// Deprecated, this class shouldn't be directly instantiated.
- (instancetype)initWithMessageID:(NSString *)messageID
                     campaignName:(NSString *)campaignName
              renderAsTestMessage:(BOOL)renderAsTestMessage
                      messageType:(FIRInAppMessagingDisplayMessageType)messageType
                      triggerType:(FIRInAppMessagingDisplayTriggerType)triggerType __deprecated;
@end

NS_SWIFT_NAME(InAppMessagingCardDisplay)
@interface FIRInAppMessagingCardDisplay : FIRInAppMessagingDisplayMessage

/**
 * Gets the title text for a card FIAM message.
 */
@property(nonatomic, nonnull, copy, readonly) NSString *title;

/**
 * Gets the body text for a card FIAM message.
 */
@property(nonatomic, nullable, copy, readonly) NSString *body;

/**
 * Gets the color for text in card FIAM message. It applies to both title and body text.
 */
@property(nonatomic, copy, nonnull, readonly) UIColor *textColor;

/**
 * Image data for the supplied portrait image for a card FIAM messasge.
 */
@property(nonatomic, nonnull, copy, readonly) FIRInAppMessagingImageData *portraitImageData;

/**
 * Image data for the supplied landscape image for a card FIAM message.
 */
@property(nonatomic, nullable, copy, readonly) FIRInAppMessagingImageData *landscapeImageData;

/**
 * The background color for a card FIAM message.
 */
@property(nonatomic, copy, nonnull, readonly) UIColor *displayBackgroundColor;

/**
 * Metadata for a card FIAM message's primary action button.
 */
@property(nonatomic, nonnull, readonly) FIRInAppMessagingActionButton *primaryActionButton;

/**
 * The action URL for a card FIAM message's primary action button.
 */
@property(nonatomic, nonnull, readonly) NSURL *primaryActionURL;

/**
 * Metadata for a card FIAM message's secondary action button.
 */
@property(nonatomic, nullable, readonly) FIRInAppMessagingActionButton *secondaryActionButton;

/**
 * The action URL for a card FIAM message's secondary action button.
 */
@property(nonatomic, nullable, readonly) NSURL *secondaryActionURL;

/// Unavailable.
- (instancetype)init NS_UNAVAILABLE;

@end

/** Class for defining a modal message for display.
 */
NS_SWIFT_NAME(InAppMessagingModalDisplay)
@interface FIRInAppMessagingModalDisplay : FIRInAppMessagingDisplayMessage

/**
 * Gets the title for a modal fiam message.
 */
@property(nonatomic, nonnull, copy, readonly) NSString *title;

/**
 * Gets the image data for a modal fiam message.
 */
@property(nonatomic, nullable, copy, readonly) FIRInAppMessagingImageData *imageData;

/**
 * Gets the body text for a modal fiam message.
 */
@property(nonatomic, nullable, copy, readonly) NSString *bodyText;

/**
 * Gets the action button metadata for a modal fiam message.
 */
@property(nonatomic, nullable, readonly) FIRInAppMessagingActionButton *actionButton;

/**
 * Gets the action URL for a modal fiam message.
 */
@property(nonatomic, nullable, readonly) NSURL *actionURL;

/**
 * Gets the background color for a modal fiam message.
 */
@property(nonatomic, copy, nonnull) UIColor *displayBackgroundColor;

/**
 * Gets the color for text in modal fiam message. It would apply to both title and body text.
 */
@property(nonatomic, copy, nonnull) UIColor *textColor;

/// Unavailable.
- (instancetype)init NS_UNAVAILABLE;

/// Deprecated, this class shouldn't be directly instantiated.
- (instancetype)initWithMessageID:(NSString *)messageID
                     campaignName:(NSString *)campaignName
              renderAsTestMessage:(BOOL)renderAsTestMessage
                      triggerType:(FIRInAppMessagingDisplayTriggerType)triggerType
                        titleText:(NSString *)title
                         bodyText:(NSString *)bodyText
                        textColor:(UIColor *)textColor
                  backgroundColor:(UIColor *)backgroundColor
                        imageData:(nullable FIRInAppMessagingImageData *)imageData
                     actionButton:(nullable FIRInAppMessagingActionButton *)actionButton
                        actionURL:(nullable NSURL *)actionURL __deprecated;
@end

/** Class for defining a banner message for display.
 */
NS_SWIFT_NAME(InAppMessagingBannerDisplay)
@interface FIRInAppMessagingBannerDisplay : FIRInAppMessagingDisplayMessage

/**
 * Gets the title of a banner message.
 */
@property(nonatomic, nonnull, copy, readonly) NSString *title;

/**
 * Gets the image data for a banner message.
 */
@property(nonatomic, nullable, copy, readonly) FIRInAppMessagingImageData *imageData;

/**
 * Gets the body text for a banner message.
 */
@property(nonatomic, nullable, copy, readonly) NSString *bodyText;

/**
 * Gets banner's background color
 */
@property(nonatomic, copy, nonnull, readonly) UIColor *displayBackgroundColor;

/**
 * Gets the color for text in banner fiam message. It would apply to both title and body text.
 */
@property(nonatomic, copy, nonnull) UIColor *textColor;

/**
 * Gets the action URL for a banner fiam message.
 */
@property(nonatomic, nullable, readonly) NSURL *actionURL;

/// Unavailable.
- (instancetype)init NS_UNAVAILABLE;

/// Deprecated, this class shouldn't be directly instantiated.
- (instancetype)initWithMessageID:(NSString *)messageID
                     campaignName:(NSString *)campaignName
              renderAsTestMessage:(BOOL)renderAsTestMessage
                      triggerType:(FIRInAppMessagingDisplayTriggerType)triggerType
                        titleText:(NSString *)title
                         bodyText:(NSString *)bodyText
                        textColor:(UIColor *)textColor
                  backgroundColor:(UIColor *)backgroundColor
                        imageData:(nullable FIRInAppMessagingImageData *)imageData
                        actionURL:(nullable NSURL *)actionURL __deprecated;
@end

/** Class for defining a image-only message for display.
 */
NS_SWIFT_NAME(InAppMessagingImageOnlyDisplay)
@interface FIRInAppMessagingImageOnlyDisplay : FIRInAppMessagingDisplayMessage

/**
 * Gets the image for this message
 */
@property(nonatomic, nonnull, copy, readonly) FIRInAppMessagingImageData *imageData;

/**
 * Gets the action URL for an image-only fiam message.
 */
@property(nonatomic, nullable, readonly) NSURL *actionURL;

/// Unavailable.
- (instancetype)init NS_UNAVAILABLE;

/// Deprecated, this class shouldn't be directly instantiated.
- (instancetype)initWithMessageID:(NSString *)messageID
                     campaignName:(NSString *)campaignName
              renderAsTestMessage:(BOOL)renderAsTestMessage
                      triggerType:(FIRInAppMessagingDisplayTriggerType)triggerType
                        imageData:(nullable FIRInAppMessagingImageData *)imageData
                        actionURL:(nullable NSURL *)actionURL __deprecated;
@end

/// The way that an in-app message was dismissed.
typedef NS_ENUM(NSInteger, FIRInAppMessagingDismissType) {
  /// Message was swiped away (only valid for banner messages).
  FIRInAppMessagingDismissTypeUserSwipe,
  /// The user tapped a button to close this message.
  FIRInAppMessagingDismissTypeUserTapClose,
  /// The message was automatically dismissed (only valid for banner messages).
  FIRInAppMessagingDismissTypeAuto,
  /// Dismiss method unknown.
  FIRInAppMessagingDismissUnspecified,
};

/// Error code for an in-app message that failed to display.
typedef NS_ENUM(NSInteger, FIAMDisplayRenderErrorType) {
  /// The image data for this in-app message is invalid.
  FIAMDisplayRenderErrorTypeImageDataInvalid,
  /// Unexpected error.
  FIAMDisplayRenderErrorTypeUnspecifiedError,
};

/**
 * A protocol defining those callbacks to be triggered by the message display component
 * under appropriate conditions.
 */
NS_SWIFT_NAME(InAppMessagingDisplayDelegate)
@protocol FIRInAppMessagingDisplayDelegate <NSObject>

@optional

/**
 * Called when the message is dismissed. Should be called from main thread.
 * @param inAppMessage the message that was dismissed.
 * @param dismissType specifies how the message is closed.
 */
- (void)messageDismissed:(FIRInAppMessagingDisplayMessage *)inAppMessage
             dismissType:(FIRInAppMessagingDismissType)dismissType;

/**
 * Called when the message's action button is followed by the user.
 * @param inAppMessage the message that was clicked.
 */
- (void)messageClicked:(FIRInAppMessagingDisplayMessage *)inAppMessage __deprecated;

/**
 * Called when the message's action button is followed by the user.
 * @param inAppMessage the message that was clicked.
 * @param action contains the text and URL for the action that was clicked.
 */
- (void)messageClicked:(FIRInAppMessagingDisplayMessage *)inAppMessage
            withAction:(FIRInAppMessagingAction *)action;

/**
 * Use this to mark a message as having gone through enough impression so that
 * headless component can make appropriate impression tracking for it.
 *
 * Calling this is optional.
 *
 * When messageDismissedWithType: or messageClicked is
 * triggered, the message would be marked as having a valid impression implicitly.
 * Use impressionDetected if the UI implementation would like to mark valid
 * impression in additional cases. One example is that the message is displayed for
 * N seconds and then the app is killed by the user. Neither
 * onMessageDismissedWithType or onMessageClicked would be triggered
 * in this case. But if the app regards this as a valid impression and does not
 * want the user to see the same message again, call impressionDetected to mark
 * a valid impression.
 * @param inAppMessage the message for which an impression was detected.
 */
- (void)impressionDetectedForMessage:(FIRInAppMessagingDisplayMessage *)inAppMessage;

/**
 * Called when the display component could not render the message due to various reason.
 * It's essential for display component to call this when error does arise. On seeing
 * this, the headless component of fiam would assume that a prior attempt to render a
 * message has finished and therefore it's ready to render a new one when conditions are
 * met. Missing this callback in failed rendering attempt would make headless
 * component think a fiam message is still being rendered and therefore suppress any
 * future message rendering.
 * @param inAppMessage the message that encountered a display error.
 */
- (void)displayErrorForMessage:(FIRInAppMessagingDisplayMessage *)inAppMessage
                         error:(NSError *)error;
@end

/**
 * The protocol that a FIAM display component must implement.
 */
NS_SWIFT_NAME(InAppMessagingDisplay)
@protocol FIRInAppMessagingDisplay

/**
 * Method for rendering a specified message on client side. It's called from main thread.
 * @param messageForDisplay the message object. It would be of one of the three message
 *   types at runtime.
 * @param displayDelegate the callback object used to trigger notifications about certain
 *        conditions related to message rendering.
 */
- (void)displayMessage:(FIRInAppMessagingDisplayMessage *)messageForDisplay
       displayDelegate:(id<FIRInAppMessagingDisplayDelegate>)displayDelegate;
@end
NS_ASSUME_NONNULL_END
