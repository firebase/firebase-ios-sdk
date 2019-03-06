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

typedef NS_ENUM(NSInteger, FIRInAppMessagingDisplayMessageType) {
  FIRInAppMessagingDisplayMessageTypeModal,
  FIRInAppMessagingDisplayMessageTypeBanner,
  FIRInAppMessagingDisplayMessageTypeImageOnly
};

typedef NS_ENUM(NSInteger, FIRInAppMessagingDisplayTriggerType) {
  FIRInAppMessagingDisplayTriggerTypeOnAppForeground,
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

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithButtonText:(NSString *)btnText
                   buttonTextColor:(UIColor *)textColor
                   backgroundColor:(UIColor *)bkgColor NS_DESIGNATED_INITIALIZER;
@end

/** Contain display data for an image for a fiam message.
 */
NS_SWIFT_NAME(InAppMessagingImageData)
@interface FIRInAppMessagingImageData : NSObject
@property(nonatomic, nonnull, copy, readonly) NSString *imageURL;

/**
 * Gets the downloaded image data. It can be null if headless component fails to load it.
 */
@property(nonatomic, readonly, nullable) NSData *imageRawData;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithImageURL:(NSString *)imageURL
                       imageData:(NSData *)imageData NS_DESIGNATED_INITIALIZER;
@end

/** Defines the metadata for the campaign to which a FIAM message belongs.
 */
@interface FIRInAppMessagingCampaignInfo : NSObject

@property(nonatomic, nonnull, copy, readonly) NSString *messageID;
@property(nonatomic, nonnull, copy, readonly) NSString *campaignName;
@property(nonatomic, readonly) BOOL renderAsTestMessage;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithMessageID:(NSString *)messageID
                     campaignName:(NSString *)campaignName
              renderAsTestMessage:(BOOL)renderAsTestMessage;

@end

/**
 * Base class representing a FIAM message to be displayed. Don't create instance
 * of this class directly. Instantiate one of its subclasses instead.
 */
NS_SWIFT_NAME(InAppMessagingDisplayMessage)
@interface FIRInAppMessagingDisplayMessage : NSObject
@property(nonatomic, copy, nonnull, readonly) FIRInAppMessagingCampaignInfo *campaignInfo;
@property(nonatomic, readonly) FIRInAppMessagingDisplayMessageType type;
@property(nonatomic, readonly) FIRInAppMessagingDisplayTriggerType triggerType;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithMessageID:(NSString *)messageID
                     campaignName:(NSString *)campaignName
              renderAsTestMessage:(BOOL)renderAsTestMessage
                      messageType:(FIRInAppMessagingDisplayMessageType)messageType
                      triggerType:(FIRInAppMessagingDisplayTriggerType)triggerType;
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

- (instancetype)init NS_UNAVAILABLE;
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
                        actionURL:(nullable NSURL *)actionURL NS_DESIGNATED_INITIALIZER;
@end

/** Class for defining a banner message for display.
 */
NS_SWIFT_NAME(InAppMessagingBannerDisplay)
@interface FIRInAppMessagingBannerDisplay : FIRInAppMessagingDisplayMessage
// Title is always required for modal messages.
@property(nonatomic, nonnull, copy, readonly) NSString *title;

// Image, body, action URL are all optional for banner messages.
@property(nonatomic, nullable, copy, readonly) FIRInAppMessagingImageData *imageData;
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

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithMessageID:(NSString *)messageID
                     campaignName:(NSString *)campaignName
              renderAsTestMessage:(BOOL)renderAsTestMessage
                      triggerType:(FIRInAppMessagingDisplayTriggerType)triggerType
                        titleText:(NSString *)title
                         bodyText:(NSString *)bodyText
                        textColor:(UIColor *)textColor
                  backgroundColor:(UIColor *)backgroundColor
                        imageData:(nullable FIRInAppMessagingImageData *)imageData
                        actionURL:(nullable NSURL *)actionURL NS_DESIGNATED_INITIALIZER;
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

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithMessageID:(NSString *)messageID
                     campaignName:(NSString *)campaignName
              renderAsTestMessage:(BOOL)renderAsTestMessage
                      triggerType:(FIRInAppMessagingDisplayTriggerType)triggerType
                        imageData:(FIRInAppMessagingImageData *)imageData
                        actionURL:(nullable NSURL *)actionURL NS_DESIGNATED_INITIALIZER;
@end

typedef NS_ENUM(NSInteger, FIRInAppMessagingDismissType) {
  FIRInAppMessagingDismissTypeUserSwipe,     // user swipes away the banner view
  FIRInAppMessagingDismissTypeUserTapClose,  // user clicks on close buttons
  FIRInAppMessagingDismissTypeAuto,          // automatic dismiss from banner view
  FIRInAppMessagingDismissUnspecified,       // message is dismissed, but not belonging to any
                                             // above dismiss category.
};

// enum integer value used in as code for NSError reported from displayErrorEncountered: callback
typedef NS_ENUM(NSInteger, FIAMDisplayRenderErrorType) {
  FIAMDisplayRenderErrorTypeImageDataInvalid,  // provided image data is not valid for image
                                               // rendering
  FIAMDisplayRenderErrorTypeUnspecifiedError,  // error not classified, mainly unexpected
                                               // failure cases
};

/**
 * A protocol defining those callbacks to be triggered by the message display component
 * under appropriate conditions.
 */
NS_SWIFT_NAME(InAppMessagingDisplayDelegate)
@protocol FIRInAppMessagingDisplayDelegate <NSObject>
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
- (void)messageClicked:(FIRInAppMessagingDisplayMessage *)inAppMessage;

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
