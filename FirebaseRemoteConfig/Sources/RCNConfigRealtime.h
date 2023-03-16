/*
 * Copyright 2022 Google LLC
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

#import <Foundation/Foundation.h>
#import "FirebaseRemoteConfig/Sources/Private/RCNConfigFetch.h"
#import "FirebaseRemoteConfig/Sources/Public/FirebaseRemoteConfig/FIRRemoteConfig.h"

@class RCNConfigSettings;

@interface RCNConfigRealtime : NSObject <NSURLSessionDataDelegate>

/// Completion handler invoked by config update methods when they get a response from the server.
///
/// @param error  Error message on failure.
typedef void (^RCNConfigUpdateCompletion)(FIRRemoteConfigUpdate *_Nullable configUpdate,
                                          NSError *_Nullable error);

- (instancetype _Nonnull)init:(RCNConfigFetch *_Nonnull)configFetch
                     settings:(RCNConfigSettings *_Nonnull)settings
                    namespace:(NSString *_Nonnull)namespace
                      options:(FIROptions *_Nonnull)options;

- (FIRConfigUpdateListenerRegistration *_Nonnull)addConfigUpdateListener:
    (RCNConfigUpdateCompletion _Nonnull)listener;
- (void)removeConfigUpdateListener:(RCNConfigUpdateCompletion _Nonnull)listener;

@end
