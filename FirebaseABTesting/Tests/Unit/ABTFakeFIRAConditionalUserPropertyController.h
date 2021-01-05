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

#import <Foundation/Foundation.h>

#import "Interop/Analytics/Public/FIRAnalyticsInterop.h"

@class FIRAConditionalUserProperty;
@class FIRAEvent;

/// Fake Firebase Analytics Conditional User Property Controller Class.
/// This is a lightweight class to test experiments set and clean, events logging in unit tests.
@interface ABTFakeFIRAConditionalUserPropertyController : NSObject

/// Returns the FIRAConditionalUserPropertyController singleton.
+ (instancetype)sharedInstance;
- (void)setConditionalUserProperty:(NSDictionary<NSString *, id> *)conditionalUserProperty;
- (void)clearConditionalUserPropertyWithName:(NSString *)conditionalUserPropertyName;
- (NSArray<FIRAConditionalUserProperty *> *)
    conditionalUserPropertiesWithNamePrefix:(NSString *)namePrefix
                             filterByOrigin:(NSString *)origin;
- (NSInteger)maxUserPropertiesForOrigin:(NSString *)origin;
- (void)resetExperiments;
@end

@interface FakeAnalytics : NSObject <FIRAnalyticsInterop> {
  ABTFakeFIRAConditionalUserPropertyController *_fakeController;
}
- (instancetype)initWithFakeController:
    (ABTFakeFIRAConditionalUserPropertyController *)fakeController;
@end
