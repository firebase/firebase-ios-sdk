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

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <Foundation/Foundation.h>

#import "FirebaseInAppMessaging/Sources/Public/FirebaseInAppMessaging/FIRInAppMessagingRendering.h"
#import "FirebaseInAppMessaging/Sources/RenderingObjects/FIRInAppMessagingRenderingPrivate.h"

@implementation FIRInAppMessagingDisplayMessage

- (instancetype)initWithMessageID:(NSString *)messageID
                     campaignName:(NSString *)campaignName
                experimentPayload:(nullable ABTExperimentPayload *)experimentPayload
              renderAsTestMessage:(BOOL)renderAsTestMessage
                      messageType:(FIRInAppMessagingDisplayMessageType)messageType
                      triggerType:(FIRInAppMessagingDisplayTriggerType)triggerType
                          appData:(NSDictionary *)appData {
  if (self = [super init]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    _campaignInfo = [[FIRInAppMessagingCampaignInfo alloc] initWithMessageID:messageID
                                                                campaignName:campaignName
                                                           experimentPayload:experimentPayload
                                                         renderAsTestMessage:renderAsTestMessage];
#pragma clang diagnostic pop
    _type = messageType;
    _triggerType = triggerType;
    _appData = [appData copy];
  }
  return self;
}

- (instancetype)initWithMessageID:(NSString *)messageID
                     campaignName:(NSString *)campaignName
              renderAsTestMessage:(BOOL)renderAsTestMessage
                      messageType:(FIRInAppMessagingDisplayMessageType)messageType
                      triggerType:(FIRInAppMessagingDisplayTriggerType)triggerType {
  return [self initWithMessageID:messageID
                    campaignName:campaignName
               experimentPayload:nil
             renderAsTestMessage:renderAsTestMessage
                     messageType:messageType
                     triggerType:triggerType
                         appData:nil];
}

@end

@implementation FIRInAppMessagingCardDisplay

- (void)setBody:(NSString *_Nullable)body {
  _body = body;
}

- (void)setLandscapeImageData:(FIRInAppMessagingImageData *_Nullable)landscapeImageData {
  _landscapeImageData = landscapeImageData;
}

- (void)setSecondaryActionButton:(FIRInAppMessagingActionButton *_Nullable)secondaryActionButton {
  _secondaryActionButton = secondaryActionButton;
}

- (void)setSecondaryActionURL:(NSURL *_Nullable)secondaryActionURL {
  _secondaryActionURL = secondaryActionURL;
}

- (instancetype)initWithMessageID:(NSString *)messageID
                     campaignName:(NSString *)campaignName
                experimentPayload:(nullable ABTExperimentPayload *)experimentPayload
              renderAsTestMessage:(BOOL)renderAsTestMessage
                      triggerType:(FIRInAppMessagingDisplayTriggerType)triggerType
                        titleText:(NSString *)title
                        textColor:(UIColor *)textColor
                portraitImageData:(FIRInAppMessagingImageData *)portraitImageData
                  backgroundColor:(UIColor *)backgroundColor
              primaryActionButton:(FIRInAppMessagingActionButton *)primaryActionButton
                 primaryActionURL:(NSURL *)primaryActionURL
                          appData:(NSDictionary *)appData {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  if (self = [super initWithMessageID:messageID
                         campaignName:campaignName
                    experimentPayload:experimentPayload
                  renderAsTestMessage:renderAsTestMessage
                          messageType:FIRInAppMessagingDisplayMessageTypeCard
                          triggerType:triggerType
                              appData:appData]) {
#pragma clang diagnostic pop
    _title = title;
    _textColor = textColor;
    _portraitImageData = portraitImageData;
    _displayBackgroundColor = backgroundColor;
    _primaryActionButton = primaryActionButton;
    _primaryActionURL = primaryActionURL;
  }
  return self;
}

- (instancetype)initWithMessageID:(NSString *)messageID
                     campaignName:(NSString *)campaignName
              renderAsTestMessage:(BOOL)renderAsTestMessage
                      triggerType:(FIRInAppMessagingDisplayTriggerType)triggerType
                        titleText:(NSString *)title
                        textColor:(UIColor *)textColor
                portraitImageData:(FIRInAppMessagingImageData *)portraitImageData
                  backgroundColor:(UIColor *)backgroundColor
              primaryActionButton:(FIRInAppMessagingActionButton *)primaryActionButton
                 primaryActionURL:(NSURL *)primaryActionURL {
  return [self initWithMessageID:messageID
                    campaignName:campaignName
               experimentPayload:nil
             renderAsTestMessage:renderAsTestMessage
                     triggerType:triggerType
                       titleText:title
                       textColor:textColor
               portraitImageData:portraitImageData
                 backgroundColor:backgroundColor
             primaryActionButton:primaryActionButton
                primaryActionURL:primaryActionURL
                         appData:nil];
}

@end

@implementation FIRInAppMessagingBannerDisplay
- (instancetype)initWithMessageID:(NSString *)messageID
                     campaignName:(NSString *)campaignName
                experimentPayload:(nullable ABTExperimentPayload *)experimentPayload
              renderAsTestMessage:(BOOL)renderAsTestMessage
                      triggerType:(FIRInAppMessagingDisplayTriggerType)triggerType
                        titleText:(NSString *)title
                         bodyText:(NSString *)bodyText
                        textColor:(UIColor *)textColor
                  backgroundColor:(UIColor *)backgroundColor
                        imageData:(nullable FIRInAppMessagingImageData *)imageData
                        actionURL:(nullable NSURL *)actionURL
                          appData:(NSDictionary *)appData {
  if (self = [super initWithMessageID:messageID
                         campaignName:campaignName
                    experimentPayload:experimentPayload
                  renderAsTestMessage:renderAsTestMessage
                          messageType:FIRInAppMessagingDisplayMessageTypeBanner
                          triggerType:triggerType
                              appData:appData]) {
    _title = title;
    _bodyText = bodyText;
    _textColor = textColor;
    _displayBackgroundColor = backgroundColor;
    _imageData = imageData;
    _actionURL = actionURL;
  }
  return self;
}

- (instancetype)initWithMessageID:(NSString *)messageID
                     campaignName:(NSString *)campaignName
              renderAsTestMessage:(BOOL)renderAsTestMessage
                      triggerType:(FIRInAppMessagingDisplayTriggerType)triggerType
                        titleText:(NSString *)title
                         bodyText:(NSString *)bodyText
                        textColor:(UIColor *)textColor
                  backgroundColor:(UIColor *)backgroundColor
                        imageData:(nullable FIRInAppMessagingImageData *)imageData
                        actionURL:(nullable NSURL *)actionURL {
  return [self initWithMessageID:messageID
                    campaignName:campaignName
               experimentPayload:nil
             renderAsTestMessage:renderAsTestMessage
                     triggerType:triggerType
                       titleText:title
                        bodyText:bodyText
                       textColor:textColor
                 backgroundColor:backgroundColor
                       imageData:imageData
                       actionURL:actionURL
                         appData:nil];
}

@end

@implementation FIRInAppMessagingModalDisplay

- (instancetype)initWithMessageID:(NSString *)messageID
                     campaignName:(NSString *)campaignName
                experimentPayload:(nullable ABTExperimentPayload *)experimentPayload
              renderAsTestMessage:(BOOL)renderAsTestMessage
                      triggerType:(FIRInAppMessagingDisplayTriggerType)triggerType
                        titleText:(NSString *)title
                         bodyText:(NSString *)bodyText
                        textColor:(UIColor *)textColor
                  backgroundColor:(UIColor *)backgroundColor
                        imageData:(nullable FIRInAppMessagingImageData *)imageData
                     actionButton:(nullable FIRInAppMessagingActionButton *)actionButton
                        actionURL:(nullable NSURL *)actionURL
                          appData:(nullable NSDictionary *)appData {
  if (self = [super initWithMessageID:messageID
                         campaignName:campaignName
                    experimentPayload:experimentPayload
                  renderAsTestMessage:renderAsTestMessage
                          messageType:FIRInAppMessagingDisplayMessageTypeModal
                          triggerType:triggerType
                              appData:appData]) {
    _title = title;
    _bodyText = bodyText;
    _textColor = textColor;
    _displayBackgroundColor = backgroundColor;
    _imageData = imageData;
    _actionButton = actionButton;
    _actionURL = actionURL;
  }
  return self;
}

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
                        actionURL:(nullable NSURL *)actionURL {
  return [self initWithMessageID:messageID
                    campaignName:campaignName
               experimentPayload:nil
             renderAsTestMessage:renderAsTestMessage
                     triggerType:triggerType
                       titleText:title
                        bodyText:bodyText
                       textColor:textColor
                 backgroundColor:backgroundColor
                       imageData:imageData
                    actionButton:actionButton
                       actionURL:actionURL
                         appData:nil];
}

@end

@implementation FIRInAppMessagingImageOnlyDisplay

- (instancetype)initWithMessageID:(NSString *)messageID
                     campaignName:(NSString *)campaignName
                experimentPayload:(nullable ABTExperimentPayload *)experimentPayload
              renderAsTestMessage:(BOOL)renderAsTestMessage
                      triggerType:(FIRInAppMessagingDisplayTriggerType)triggerType
                        imageData:(nullable FIRInAppMessagingImageData *)imageData
                        actionURL:(nullable NSURL *)actionURL
                          appData:(nullable NSDictionary *)appData {
  if (self = [super initWithMessageID:messageID
                         campaignName:campaignName
                    experimentPayload:experimentPayload
                  renderAsTestMessage:renderAsTestMessage
                          messageType:FIRInAppMessagingDisplayMessageTypeModal
                          triggerType:triggerType
                              appData:appData]) {
    _imageData = imageData;
    _actionURL = actionURL;
  }
  return self;
}

- (instancetype)initWithMessageID:(NSString *)messageID
                     campaignName:(NSString *)campaignName
              renderAsTestMessage:(BOOL)renderAsTestMessage
                      triggerType:(FIRInAppMessagingDisplayTriggerType)triggerType
                        imageData:(nullable FIRInAppMessagingImageData *)imageData
                        actionURL:(nullable NSURL *)actionURL {
  return [self initWithMessageID:messageID
                    campaignName:campaignName
               experimentPayload:nil
             renderAsTestMessage:renderAsTestMessage
                     triggerType:triggerType
                       imageData:imageData
                       actionURL:actionURL
                         appData:nil];
}

@end

@implementation FIRInAppMessagingActionButton

- (instancetype)initWithButtonText:(NSString *)btnText
                   buttonTextColor:(UIColor *)textColor
                   backgroundColor:(UIColor *)bkgColor {
  if (self = [super init]) {
    _buttonText = btnText;
    _buttonTextColor = textColor;
    _buttonBackgroundColor = bkgColor;
  }
  return self;
}
@end

@implementation FIRInAppMessagingImageData
- (instancetype)initWithImageURL:(NSString *)imageURL imageData:(NSData *)imageData {
  if (self = [super init]) {
    _imageURL = imageURL;
    _imageRawData = imageData;
  }
  return self;
}

- (id)copyWithZone:(NSZone *)zone {
  FIRInAppMessagingImageData *imageData = [[[self class] allocWithZone:zone] init];
  imageData->_imageURL = [_imageURL copyWithZone:zone];
  imageData->_imageRawData = [_imageRawData copyWithZone:zone];

  return imageData;
}

@end

@interface FIRInAppMessagingCampaignInfo ()

/**
 * Optional experiment metadata for this message.
 */
@property(nonatomic, nullable, copy, readonly) ABTExperimentPayload *experimentPayload;

@end

@implementation FIRInAppMessagingCampaignInfo
- (instancetype)initWithMessageID:(NSString *)messageID
                     campaignName:(NSString *)campaignName
                experimentPayload:(nullable ABTExperimentPayload *)experimentPayload
              renderAsTestMessage:(BOOL)renderAsTestMessage {
  if (self = [super init]) {
    _messageID = messageID;
    _campaignName = campaignName;
    _experimentPayload = experimentPayload;
    _renderAsTestMessage = renderAsTestMessage;
  }
  return self;
}

- (instancetype)initWithMessageID:(NSString *)messageID
                     campaignName:(NSString *)campaignName
              renderAsTestMessage:(BOOL)renderAsTestMessage {
  return [self initWithMessageID:messageID
                    campaignName:campaignName
               experimentPayload:nil
             renderAsTestMessage:renderAsTestMessage];
}
@end

@implementation FIRInAppMessagingAction

- (instancetype)initWithActionText:(nullable NSString *)actionText
                         actionURL:(nullable NSURL *)actionURL {
  if (self = [super init]) {
    _actionText = actionText;
    _actionURL = actionURL;
  }
  return self;
}

@end

#endif  // TARGET_OS_IOS
