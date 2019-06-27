/*
 * Copyright 2017 Google
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

#import <FirebaseCore/FIRLogger.h>

#import "FIRCore+InAppMessaging.h"
#import "FIRIAMDisplayTriggerDefinition.h"
#import "FIRIAMFetchResponseParser.h"
#import "FIRIAMMessageContentData.h"
#import "FIRIAMMessageContentDataWithImageURL.h"
#import "FIRIAMMessageDefinition.h"
#import "FIRIAMTimeFetcher.h"
#import "UIColor+FIRIAMHexString.h"

@interface FIRIAMFetchResponseParser ()
@property(nonatomic) id<FIRIAMTimeFetcher> timeFetcher;
@end

@implementation FIRIAMFetchResponseParser

- (instancetype)initWithTimeFetcher:(id<FIRIAMTimeFetcher>)timeFetcher {
  if (self = [super init]) {
    _timeFetcher = timeFetcher;
  }
  return self;
}

- (NSArray<FIRIAMMessageDefinition *> *)parseAPIResponseDictionary:(NSDictionary *)responseDict
                                                 discardedMsgCount:(NSInteger *)discardCount
                                            fetchWaitTimeInSeconds:(NSNumber **)fetchWaitTime {
  if (fetchWaitTime != nil) {
    *fetchWaitTime = nil;  // It would be set to non nil value if it's detected in responseDict
    if ([responseDict[@"expirationEpochTimestampMillis"] isKindOfClass:NSString.class]) {
      NSTimeInterval nextFetchTimeInResponse =
          [responseDict[@"expirationEpochTimestampMillis"] doubleValue] / 1000;
      NSTimeInterval fetchWaitTimeInSeconds =
          nextFetchTimeInResponse - [self.timeFetcher currentTimestampInSeconds];

      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM900005",
                  @"Detected next fetch epoch time in API response as %f seconds and wait for %f "
                   "seconds before next fetch.",
                  nextFetchTimeInResponse, fetchWaitTimeInSeconds);

      if (fetchWaitTimeInSeconds > 0.01) {
        *fetchWaitTime = @(fetchWaitTimeInSeconds);
        FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM900018",
                    @"Fetch wait time calculated from server response is negative. Discard it.");
      }
    } else {
      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM900014",
                  @"No fetch epoch time detected in API response.");
    }
  }

  NSArray<NSDictionary *> *messageArray = responseDict[@"messages"];
  NSInteger discarded = 0;

  NSMutableArray<FIRIAMMessageDefinition *> *definitions = [[NSMutableArray alloc] init];
  for (NSDictionary *nextMsg in messageArray) {
    FIRIAMMessageDefinition *nextDefinition =
        [self convertToMessageDefinitionWithMessageDict:nextMsg];
    if (nextDefinition) {
      [definitions addObject:nextDefinition];
    } else {
      FIRLogInfo(kFIRLoggerInAppMessaging, @"I-IAM900001",
                 @"No definition generated for message node %@", nextMsg);
      discarded++;
    }
  }
  FIRLogDebug(
      kFIRLoggerInAppMessaging, @"I-IAM900002",
      @"%lu message definitions were parsed out successfully and %lu messages are discarded",
      (unsigned long)definitions.count, (unsigned long)discarded);

  if (discardCount) {
    *discardCount = discarded;
  }
  return [definitions copy];
}

// Return nil if no valid triggering condition can be detected
- (NSArray<FIRIAMDisplayTriggerDefinition *> *)parseTriggeringCondition:
    (NSArray<NSDictionary *> *)triggerConditions {
  if (triggerConditions == nil || triggerConditions.count == 0) {
    return nil;
  }

  NSMutableArray<FIRIAMDisplayTriggerDefinition *> *triggers = [[NSMutableArray alloc] init];

  for (NSDictionary *nextTriggerCondition in triggerConditions) {
    // Handle app_launch and on_foreground cases.
    if (nextTriggerCondition[@"fiamTrigger"]) {
      if ([nextTriggerCondition[@"fiamTrigger"] isEqualToString:@"ON_FOREGROUND"]) {
        [triggers addObject:[[FIRIAMDisplayTriggerDefinition alloc] initForAppForegroundTrigger]];
      } else if ([nextTriggerCondition[@"fiamTrigger"] isEqualToString:@"APP_LAUNCH"]) {
        [triggers addObject:[[FIRIAMDisplayTriggerDefinition alloc] initForAppLaunchTrigger]];
      }
    } else if ([nextTriggerCondition[@"event"] isKindOfClass:[NSDictionary class]]) {
      NSDictionary *triggeringEvent = (NSDictionary *)nextTriggerCondition[@"event"];
      if (triggeringEvent[@"name"]) {
        [triggers addObject:[[FIRIAMDisplayTriggerDefinition alloc]
                                initWithFirebaseAnalyticEvent:triggeringEvent[@"name"]]];
      }
    }
  }

  return [triggers copy];
}

// For one element in the restful API response's messages array, convert into
// a FIRIAMMessageDefinition object. If the conversion fails, a nil is returned.
- (FIRIAMMessageDefinition *)convertToMessageDefinitionWithMessageDict:(NSDictionary *)messageNode {
  @try {
    BOOL isTestMessage = NO;

    id isTestCampaignNode = messageNode[@"isTestCampaign"];
    if ([isTestCampaignNode isKindOfClass:[NSNumber class]]) {
      isTestMessage = [isTestCampaignNode boolValue];
    }

    id vanillaPayloadNode = messageNode[@"vanillaPayload"];
    if (![vanillaPayloadNode isKindOfClass:[NSDictionary class]]) {
      FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM900012",
                    @"vanillaPayload does not exist or does not represent a dictionary in "
                     "message node %@",
                    messageNode);
      return nil;
    }

    NSString *messageID = vanillaPayloadNode[@"campaignId"];
    if (!messageID) {
      FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM900010",
                    @"messsage id is missing in message node %@", messageNode);
      return nil;
    }

    NSString *messageName = vanillaPayloadNode[@"campaignName"];
    if (!messageName && !isTestMessage) {
      FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM900011",
                    @"campaign name is missing in non-test message node %@", messageNode);
      return nil;
    }

    NSTimeInterval startTimeInSeconds = 0;
    NSTimeInterval endTimeInSeconds = 0;
    if (!isTestMessage) {
      // Parsing start/end times out of non-test messages. They are strings in the
      // json response.
      id startTimeNode = vanillaPayloadNode[@"campaignStartTimeMillis"];
      if ([startTimeNode isKindOfClass:[NSString class]]) {
        startTimeInSeconds = [startTimeNode doubleValue] / 1000.0;
      }

      id endTimeNode = vanillaPayloadNode[@"campaignEndTimeMillis"];
      if ([endTimeNode isKindOfClass:[NSString class]]) {
        endTimeInSeconds = [endTimeNode doubleValue] / 1000.0;
      }
    }

    id contentNode = messageNode[@"content"];
    if (![contentNode isKindOfClass:[NSDictionary class]]) {
      FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM900013",
                    @"content node does not exist or does not represent a dictionary in "
                     "message node %@",
                    messageNode);
      return nil;
    }

    NSDictionary *content = (NSDictionary *)contentNode;
    FIRIAMRenderingMode mode;
    UIColor *viewCardBackgroundColor, *btnBgColor, *btnTxtColor, *secondaryBtnTxtColor,
        *titleTextColor;
    viewCardBackgroundColor = btnBgColor = btnTxtColor = titleTextColor = nil;

    NSString *title, *body, *imageURLStr, *landscapeImageURLStr, *actionURLStr,
        *secondaryActionURLStr, *actionButtonText, *secondaryActionButtonText;
    title = body = imageURLStr = landscapeImageURLStr = actionButtonText =
        secondaryActionButtonText = actionURLStr = secondaryActionURLStr = nil;

    // TODO: Refactor this giant if-else block into separate parsing methods per message type.
    if ([content[@"banner"] isKindOfClass:[NSDictionary class]]) {
      NSDictionary *bannerNode = (NSDictionary *)contentNode[@"banner"];
      mode = FIRIAMRenderAsBannerView;

      title = bannerNode[@"title"][@"text"];
      titleTextColor = [UIColor firiam_colorWithHexString:bannerNode[@"title"][@"hexColor"]];

      body = bannerNode[@"body"][@"text"];

      imageURLStr = bannerNode[@"imageUrl"];
      actionURLStr = bannerNode[@"action"][@"actionUrl"];
      viewCardBackgroundColor =
          [UIColor firiam_colorWithHexString:bannerNode[@"backgroundHexColor"]];

    } else if ([content[@"modal"] isKindOfClass:[NSDictionary class]]) {
      mode = FIRIAMRenderAsModalView;

      NSDictionary *modalNode = (NSDictionary *)contentNode[@"modal"];
      title = modalNode[@"title"][@"text"];
      titleTextColor = [UIColor firiam_colorWithHexString:modalNode[@"title"][@"hexColor"]];

      body = modalNode[@"body"][@"text"];

      imageURLStr = modalNode[@"imageUrl"];
      actionButtonText = modalNode[@"actionButton"][@"text"][@"text"];
      btnBgColor =
          [UIColor firiam_colorWithHexString:modalNode[@"actionButton"][@"buttonHexColor"]];

      actionURLStr = modalNode[@"action"][@"actionUrl"];
      viewCardBackgroundColor =
          [UIColor firiam_colorWithHexString:modalNode[@"backgroundHexColor"]];
    } else if ([content[@"imageOnly"] isKindOfClass:[NSDictionary class]]) {
      mode = FIRIAMRenderAsImageOnlyView;
      NSDictionary *imageOnlyNode = (NSDictionary *)contentNode[@"imageOnly"];

      imageURLStr = imageOnlyNode[@"imageUrl"];

      if (!imageURLStr) {
        FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM900007",
                      @"Image url is missing for image-only message %@", messageNode);
        return nil;
      }
      actionURLStr = imageOnlyNode[@"action"][@"actionUrl"];
    } else if ([content[@"card"] isKindOfClass:[NSDictionary class]]) {
      mode = FIRIAMRenderAsCardView;
      NSDictionary *cardNode = (NSDictionary *)contentNode[@"card"];
      title = cardNode[@"title"][@"text"];
      titleTextColor = [UIColor firiam_colorWithHexString:cardNode[@"title"][@"hexColor"]];

      body = cardNode[@"body"][@"text"];

      imageURLStr = cardNode[@"portraitImageUrl"];
      landscapeImageURLStr = cardNode[@"landscapeImageUrl"];

      viewCardBackgroundColor = [UIColor firiam_colorWithHexString:cardNode[@"backgroundHexColor"]];

      actionButtonText = cardNode[@"primaryActionButton"][@"text"][@"text"];
      btnTxtColor = [UIColor
          firiam_colorWithHexString:cardNode[@"primaryActionButton"][@"text"][@"hexColor"]];

      secondaryActionButtonText = cardNode[@"secondaryActionButton"][@"text"][@"text"];
      secondaryBtnTxtColor = [UIColor
          firiam_colorWithHexString:cardNode[@"secondaryActionButton"][@"text"][@"hexColor"]];

      actionURLStr = cardNode[@"primaryAction"][@"actionUrl"];
      secondaryActionURLStr = cardNode[@"secondaryAction"][@"actionUrl"];

    } else {
      // Unknown message type
      FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM900003",
                    @"Unknown message type in message node %@", messageNode);
      return nil;
    }

    if (title == nil && mode != FIRIAMRenderAsImageOnlyView) {
      FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM900004",
                    @"Title text is missing in message node %@", messageNode);
      return nil;
    }

    NSURL *imageURL = (imageURLStr.length == 0) ? nil : [NSURL URLWithString:imageURLStr];
    NSURL *landscapeImageURL =
        (landscapeImageURLStr.length == 0) ? nil : [NSURL URLWithString:landscapeImageURLStr];
    NSURL *actionURL = (actionURLStr.length == 0) ? nil : [NSURL URLWithString:actionURLStr];
    NSURL *secondaryActionURL =
        (secondaryActionURLStr.length == 0) ? nil : [NSURL URLWithString:secondaryActionURLStr];
    FIRIAMRenderingEffectSetting *renderEffect =
        [FIRIAMRenderingEffectSetting getDefaultRenderingEffectSetting];
    renderEffect.viewMode = mode;

    if (viewCardBackgroundColor) {
      renderEffect.displayBGColor = viewCardBackgroundColor;
    }

    if (btnBgColor) {
      renderEffect.btnBGColor = btnBgColor;
    }

    if (btnTxtColor) {
      renderEffect.btnTextColor = btnTxtColor;
    }

    if (secondaryBtnTxtColor) {
      renderEffect.secondaryActionBtnTextColor = secondaryBtnTxtColor;
    }

    if (titleTextColor) {
      renderEffect.textColor = titleTextColor;
    }

    NSArray<FIRIAMDisplayTriggerDefinition *> *triggersDefinition =
        [self parseTriggeringCondition:messageNode[@"triggeringConditions"]];

    if (isTestMessage) {
      FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM900008",
                    @"A test message with id %@ was parsed successfully.", messageID);
      renderEffect.isTestMessage = YES;
    } else {
      // Triggering definitions should always be present for a non-test message.
      if (!triggersDefinition || triggersDefinition.count == 0) {
        FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM900009",
                      @"No valid triggering condition is detected in message definition"
                       " with id %@",
                      messageID);
        return nil;
      }
    }

    FIRIAMMessageContentDataWithImageURL *msgData =
        [[FIRIAMMessageContentDataWithImageURL alloc] initWithMessageTitle:title
                                                               messageBody:body
                                                          actionButtonText:actionButtonText
                                                 secondaryActionButtonText:secondaryActionButtonText
                                                                 actionURL:actionURL
                                                        secondaryActionURL:secondaryActionURL
                                                                  imageURL:imageURL
                                                         landscapeImageURL:landscapeImageURL
                                                           usingURLSession:nil];

    FIRIAMMessageRenderData *renderData =
        [[FIRIAMMessageRenderData alloc] initWithMessageID:messageID
                                               messageName:messageName
                                               contentData:msgData
                                           renderingEffect:renderEffect];

    if (isTestMessage) {
      return [[FIRIAMMessageDefinition alloc] initTestMessageWithRenderData:renderData];
    } else {
      return [[FIRIAMMessageDefinition alloc] initWithRenderData:renderData
                                                       startTime:startTimeInSeconds
                                                         endTime:endTimeInSeconds
                                               triggerDefinition:triggersDefinition];
    }
  } @catch (NSException *e) {
    FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM900006",
                  @"Error in parsing message node %@ "
                   "with error %@",
                  messageNode, e);
    return nil;
  }
}
@end
