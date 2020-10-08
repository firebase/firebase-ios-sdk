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

#import "FirebaseRemoteConfig/Sources/RCNPersonalization.h"

#import "FirebaseRemoteConfig/Sources/RCNConfigConstants.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigValue_Internal.h"

@implementation RCNPersonalization

+ (instancetype)sharedInstance {
  static RCNPersonalization *sharedInstance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[RCNPersonalization alloc] init];
  });
  return sharedInstance;
}

+ (void)setAnalytics:(id<FIRAnalyticsInterop> _Nullable)analytics {
  RCNPersonalization *personalization = [RCNPersonalization sharedInstance];
  personalization->_analytics = analytics;
}

+ (void)logArmActive:(NSString *)key config:(NSDictionary *)config {
  NSDictionary *ids = config[RCNFetchResponseKeyPersonalizationMetadata];
  NSDictionary<NSString *, FIRRemoteConfigValue *> *values = config[RCNFetchResponseKeyEntries];
  if (ids.count < 1 || values.count < 1 || !values[key]) {
    return;
  }

  NSDictionary *metadata = ids[key];
  if (!metadata || metadata[kPersonalizationId] == nil) {
    return;
  }

  RCNPersonalization *personalization = [RCNPersonalization sharedInstance];
  [personalization->_analytics logEventWithOrigin:kAnalyticsOriginPersonalization
                                             name:kAnalyticsPullEvent
                                       parameters:@{
                                         kArmKey : metadata[kPersonalizationId],
                                         kArmValue : values[key].stringValue
                                       }];
}

@end
