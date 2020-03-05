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

@class ABTExperimentPayload;

NS_ASSUME_NONNULL_BEGIN

@interface FIRInAppMessagingCardDisplay (Private)

- (void)setBody:(NSString *_Nullable)body;
- (void)setLandscapeImageData:(FIRInAppMessagingImageData *_Nullable)landscapeImageData;
- (void)setSecondaryActionButton:(FIRInAppMessagingActionButton *_Nullable)secondaryActionButton;
- (void)setSecondaryActionURL:(NSURL *_Nullable)secondaryActionURL;

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
                 primaryActionURL:(nullable NSURL *)primaryActionURL
                          appData:(nullable NSDictionary *)appData;

@end

@interface FIRInAppMessagingActionButton (Private)

- (instancetype)initWithButtonText:(NSString *)btnText
                   buttonTextColor:(UIColor *)textColor
                   backgroundColor:(UIColor *)bkgColor;

@end

@interface FIRInAppMessagingImageData (Private)

- (instancetype)initWithImageURL:(NSString *)imageURL imageData:(NSData *)imageData;

@end

@interface FIRInAppMessagingCampaignInfo (Private)

- (nullable ABTExperimentPayload *)experimentPayload;

- (instancetype)initWithMessageID:(NSString *)messageID
                     campaignName:(NSString *)campaignName
                experimentPayload:(nullable ABTExperimentPayload *)experimentPayload
              renderAsTestMessage:(BOOL)renderAsTestMessage;

@end

@interface FIRInAppMessagingAction (Private)

- (instancetype)initWithActionText:(nullable NSString *)actionText actionURL:(NSURL *)actionURL;

@end

@interface FIRInAppMessagingDisplayMessage (Private)

- (instancetype)initWithMessageID:(NSString *)messageID
                     campaignName:(NSString *)campaignName
                experimentPayload:(nullable ABTExperimentPayload *)experimentPayload
              renderAsTestMessage:(BOOL)renderAsTestMessage
                      messageType:(FIRInAppMessagingDisplayMessageType)messageType
                      triggerType:(FIRInAppMessagingDisplayTriggerType)triggerType
                          appData:(nullable NSDictionary *)appData;

@end

@interface FIRInAppMessagingModalDisplay (Private)

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
                          appData:(nullable NSDictionary *)appData;

@end

@interface FIRInAppMessagingBannerDisplay (Private)

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
                          appData:(nullable NSDictionary *)appData;

@end

@interface FIRInAppMessagingImageOnlyDisplay (Private)

- (instancetype)initWithMessageID:(NSString *)messageID
                     campaignName:(NSString *)campaignName
                experimentPayload:(nullable ABTExperimentPayload *)experimentPayload
              renderAsTestMessage:(BOOL)renderAsTestMessage
                      triggerType:(FIRInAppMessagingDisplayTriggerType)triggerType
                        imageData:(nullable FIRInAppMessagingImageData *)imageData
                        actionURL:(nullable NSURL *)actionURL
                          appData:(nullable NSDictionary *)appData;

@end

NS_ASSUME_NONNULL_END
