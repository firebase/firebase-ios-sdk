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

- (instancetype)initWithAnalytics:(id<FIRAnalyticsInterop> _Nullable)analytics {
  self = [super init];
  if (self) {
    self->_analytics = analytics;
    self->_loggedChoiceIds = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)logArmActive:(NSString *)rcParameter config:(NSDictionary *)config {
  NSDictionary *ids = config[RCNFetchResponseKeyPersonalizationMetadata];
  NSDictionary<NSString *, FIRRemoteConfigValue *> *values = config[RCNFetchResponseKeyEntries];
  if (![ids isKindOfClass:[NSDictionary class]] || ![values isKindOfClass:[NSDictionary class]] ||
      ids.count < 1 || values.count < 1 || !values[rcParameter]) {
    return;
  }

  NSDictionary *metadata = ids[rcParameter];
  if (![metadata isKindOfClass:[NSDictionary class]]) {
    return;
  }

  // JSON null parses as NSNull, so check the type of each server-provided field, not just its
  // presence.
  NSString *choiceId = metadata[kChoiceId];
  if (![choiceId isKindOfClass:[NSString class]]) {
    return;
  }

  // Listeners like logArmActive() are dispatched to a serial queue, so loggedChoiceIds should
  // contain any previously logged RC parameter / choice ID pairs.
  if (self->_loggedChoiceIds[rcParameter] == choiceId) {
    return;
  }
  self->_loggedChoiceIds[rcParameter] = choiceId;

  // Optional fields that are missing or have an unexpected type are omitted from the event.
  NSMutableDictionary<NSString *, id> *parameters = [[NSMutableDictionary alloc] init];
  parameters[kExternalRcParameterParam] = rcParameter;
  parameters[kExternalArmValueParam] = values[rcParameter].stringValue;
  id personalizationId = metadata[kPersonalizationId];
  if ([personalizationId isKindOfClass:[NSString class]]) {
    parameters[kExternalPersonalizationIdParam] = personalizationId;
  }
  id armIndex = metadata[kArmIndex];
  if ([armIndex isKindOfClass:[NSNumber class]]) {
    parameters[kExternalArmIndexParam] = armIndex;
  }
  id group = metadata[kGroup];
  if ([group isKindOfClass:[NSString class]]) {
    parameters[kExternalGroupParam] = group;
  }

  [self->_analytics logEventWithOrigin:kAnalyticsOriginPersonalization
                                  name:kExternalEvent
                            parameters:parameters];

  [self->_analytics logEventWithOrigin:kAnalyticsOriginPersonalization
                                  name:kInternalEvent
                            parameters:@{kInternalChoiceIdParam : choiceId}];
}

@end
