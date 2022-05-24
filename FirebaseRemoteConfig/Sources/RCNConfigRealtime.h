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

#ifndef RCNConfigRealtime_h
#define RCNConfigRealtime_h

#import <Foundation/Foundation.h>
#import "FirebaseRemoteConfig/Sources/Private/RCNConfigFetch.h"
#import "FirebaseRemoteConfig/Sources/Private/RCNConfigSettings.h"
#import "FirebaseRemoteConfig/Sources/Public/FirebaseRemoteConfig/FIRRemoteConfig.h"

@interface RCNConfigRealtime : NSObject <NSURLSessionDataDelegate>

- (instancetype _Nonnull)init:(RCNConfigFetch *_Nonnull)configFetch
                     settings:(RCNConfigSettings *_Nonnull)settings
                    namespace:(NSString *_Nonnull)namespace
                      options:(FIROptions *_Nonnull)options;

- (FIRConfigUpdateListenerRegistration *_Nonnull)addConfigUpdateListener:
    (void (^_Nonnull)(NSError *_Nullable error))listener;
- (void)removeConfigUpdateListener:(void (^_Nonnull)(NSError *_Nullable error))listener;

@end

#endif /* RCNConfigRealtime_h */