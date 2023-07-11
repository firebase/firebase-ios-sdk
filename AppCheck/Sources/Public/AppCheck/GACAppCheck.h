/*
 * Copyright 2020 Google LLC
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

#import <AppCheckInterop/AppCheckInterop.h>

@class GACAppCheckToken;
@protocol GACAppCheckProvider;
@protocol GACAppCheckSettingsProtocol;
@protocol GACAppCheckTokenDelegate;

NS_ASSUME_NONNULL_BEGIN

/// A class used to manage App Check tokens for a given resource.
NS_SWIFT_NAME(InternalAppCheck)
@interface GACAppCheck : NSObject <GACAppCheckInterop>

- (instancetype)init NS_UNAVAILABLE;

/// Returns an instance of `AppCheck` for an application.
/// @param appCheckProvider  An `InternalAppCheckProvider` instance that provides App Check tokens.
/// @return An instance of `AppCheck` corresponding to the provided `app`.
- (instancetype)initWithInstanceName:(NSString *)instanceName
                    appCheckProvider:(id<GACAppCheckProvider>)appCheckProvider
                            settings:(id<GACAppCheckSettingsProtocol>)settings
                       tokenDelegate:(id<GACAppCheckTokenDelegate>)tokenDelegate
                        resourceName:(NSString *)resourceName
                 keychainAccessGroup:(nullable NSString *)accessGroup;

@end

NS_ASSUME_NONNULL_END
