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

#import "FIRIAMMessageDefinition.h"

@implementation FIRIAMMessageRenderData

- (instancetype)initWithMessageID:(NSString *)messageID
                      messageName:(NSString *)messageName
                      contentData:(id<FIRIAMMessageContentData>)contentData
                  renderingEffect:(FIRIAMRenderingEffectSetting *)renderEffect {
  if (self = [super init]) {
    _contentData = contentData;
    _renderingEffectSettings = renderEffect;
    _messageID = [messageID copy];
    _name = [messageName copy];
  }
  return self;
}
@end

@implementation FIRIAMMessageDefinition
- (instancetype)initWithRenderData:(FIRIAMMessageRenderData *)renderData
                         startTime:(NSTimeInterval)startTime
                           endTime:(NSTimeInterval)endTime
                 triggerDefinition:(NSArray<FIRIAMDisplayTriggerDefinition *> *)renderTriggers {
  if (self = [super init]) {
    _renderData = renderData;
    _renderTriggers = renderTriggers;
    _startTime = startTime;
    _endTime = endTime;
    _isTestMessage = NO;
  }
  return self;
}

- (instancetype)initTestMessageWithRenderData:(FIRIAMMessageRenderData *)renderData {
  if (self = [super init]) {
    _renderData = renderData;
    _isTestMessage = YES;
  }
  return self;
}

- (BOOL)messageHasExpired {
  return self.endTime < [[NSDate date] timeIntervalSince1970];
}

- (BOOL)messageRenderedOnTrigger:(FIRIAMRenderTrigger)trigger {
  for (FIRIAMDisplayTriggerDefinition *nextTrigger in self.renderTriggers) {
    if (nextTrigger.triggerType == trigger) {
      return YES;
    }
  }
  return NO;
}

- (BOOL)messageRenderedOnAnalyticsEvent:(NSString *)eventName {
  for (FIRIAMDisplayTriggerDefinition *nextTrigger in self.renderTriggers) {
    if (nextTrigger.triggerType == FIRIAMRenderTriggerOnFirebaseAnalyticsEvent &&
        [nextTrigger.firebaseEventName isEqualToString:eventName]) {
      return YES;
    }
  }
  return NO;
}

- (BOOL)messageHasStarted {
  return self.startTime < [[NSDate date] timeIntervalSince1970];
}
@end
