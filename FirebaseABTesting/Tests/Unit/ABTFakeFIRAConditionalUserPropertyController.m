// Copyright 2019 Google
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

#import "FirebaseABTesting/Tests/Unit/ABTFakeFIRAConditionalUserPropertyController.h"

@implementation ABTFakeFIRAConditionalUserPropertyController {
  NSMutableArray<NSDictionary<NSString *, id> *> *_experiments;
}

+ (instancetype)sharedInstance {
  static ABTFakeFIRAConditionalUserPropertyController *sharedInstance = nil;
  static dispatch_once_t onceToken = 0;

  dispatch_once(&onceToken, ^{
    sharedInstance = [[ABTFakeFIRAConditionalUserPropertyController alloc] init];
  });
  return sharedInstance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _experiments = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)setConditionalUserProperty:(NSDictionary<NSString *, id> *)cupProperties {
  [_experiments addObject:cupProperties];
}

- (void)clearConditionalUserPropertyWithName:(NSString *)conditionalUserPropertyName {
  for (NSDictionary<NSString *, id> *experiment in _experiments) {
    if ([experiment[@"name"] isEqualToString:conditionalUserPropertyName]) {
      [_experiments removeObject:experiment];
      return;
    }
  }
}

- (NSArray<FIRAConditionalUserProperty *> *)
    conditionalUserPropertiesWithNamePrefix:(NSString *)namePrefix
                             filterByOrigin:(NSString *)origin {
  return [_experiments copy];
}

/// Returns the max number of User Properties for the given origin.
- (NSInteger)maxUserPropertiesForOrigin:(NSString *)origin {
  return 3;
}

- (void)resetExperiments {
  [_experiments removeAllObjects];
}
@end

@implementation FakeAnalytics

- (instancetype)initWithFakeController:
    (ABTFakeFIRAConditionalUserPropertyController *)fakeController {
  self = [super init];
  if (self) {
    _fakeController = fakeController;
  }
  return self;
}

- (nonnull NSArray<FIRAConditionalUserProperty *> *)
    conditionalUserProperties:(nonnull NSString *)origin
           propertyNamePrefix:(nonnull NSString *)propertyNamePrefix {
  return [_fakeController conditionalUserPropertiesWithNamePrefix:propertyNamePrefix
                                                   filterByOrigin:origin];
}

- (void)clearConditionalUserProperty:(nonnull NSString *)userPropertyName
                           forOrigin:(NSString *)origin
                      clearEventName:(nonnull NSString *)clearEventName
                clearEventParameters:
                    (nonnull NSDictionary<NSString *, NSString *> *)clearEventParameters {
  [_fakeController clearConditionalUserPropertyWithName:userPropertyName];
}

- (void)setConditionalUserProperty:(nonnull NSDictionary<NSString *, id> *)conditionalUserProperty {
  [_fakeController setConditionalUserProperty:conditionalUserProperty];
}

- (NSInteger)maxUserProperties:(nonnull NSString *)origin {
  return 3;
}

- (void)setConditionalUserPropertyControllerProperties:(NSDictionary<NSString *, id> *)properties {
  for (NSString *key in properties) {
    [[ABTFakeFIRAConditionalUserPropertyController sharedInstance]
        setValue:[properties objectForKey:key]
          forKey:key];
  }
}

- (FIRAEvent *)eventWithOrigin:(NSString *)origin
                     eventName:(NSString *)eventName
                        params:(NSDictionary<NSString *, NSString *> *)params {
  return nil;
}

// Stubs
- (void)logEventWithOrigin:(nonnull NSString *)origin
                      name:(nonnull NSString *)name
                parameters:(nullable NSDictionary<NSString *, id> *)parameters {
}

- (void)setUserPropertyWithOrigin:(nonnull NSString *)origin
                             name:(nonnull NSString *)name
                            value:(nonnull id)value {
}

- (void)checkLastNotificationForOrigin:(nonnull NSString *)origin
                                 queue:(nonnull dispatch_queue_t)queue
                              callback:(nonnull void (^)(NSString *_Nullable))
                                           currentLastNotificationProperty {
}

- (void)registerAnalyticsListener:(nonnull id<FIRAnalyticsInteropListener>)listener
                       withOrigin:(nonnull NSString *)origin {
}

- (void)unregisterAnalyticsListenerWithOrigin:(nonnull NSString *)origin {
}

- (void)getUserPropertiesWithCallback:(nonnull FIRAInteropUserPropertiesCallback)callback {
}
@end
