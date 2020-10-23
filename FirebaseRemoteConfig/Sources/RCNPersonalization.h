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

#import "Interop/Analytics/Public/FIRAnalyticsInterop.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const kAnalyticsOriginPersonalization = @"fp";
static NSString *const kAnalyticsPullEvent = @"_fpc";
static NSString *const kArmKey = @"_fpid";
static NSString *const kArmValue = @"_fpct";
static NSString *const kPersonalizationId = @"personalizationId";

@interface RCNPersonalization : NSObject

/// Analytics connector
@property(nonatomic, strong) id<FIRAnalyticsInterop> _Nullable analytics;

- (instancetype)init NS_UNAVAILABLE;

/// Designated initializer.
- (instancetype)initWithAnalytics:(id<FIRAnalyticsInterop> _Nullable)analytics
    NS_DESIGNATED_INITIALIZER;

/// Called when an arm is pulled from Remote Config. If the arm is personalized, log information to
/// Google in another thread.
- (void)logArmActive:(NSString *)key config:(NSDictionary *)config;

@end

NS_ASSUME_NONNULL_END
