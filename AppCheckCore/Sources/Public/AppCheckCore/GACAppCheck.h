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

@import AppCheckCoreInterop;

@class GACAppCheckToken;
@protocol GACAppCheckProvider;
@protocol GACAppCheckSettingsProtocol;
@protocol GACAppCheckTokenDelegate;

NS_ASSUME_NONNULL_BEGIN

/// A class used to manage App Check tokens for a given resource.
NS_SWIFT_NAME(AppCheckCore)
@interface GACAppCheck : NSObject <GACAppCheckInterop>

- (instancetype)init NS_UNAVAILABLE;

/// Returns an instance of `AppCheck` for an application.
/// @param serviceName A unique identifier for the App Check instance, may be a Firebase App Name
/// or an SDK name.
/// @param resourceName The name of the resource protected by App Check; for a Firebase App this is
/// "projects/{project_id}/apps/{app_id}".
/// @param appCheckProvider  An object that provides App Check tokens.
/// @param settings An object that provides App Check settings.
/// @param tokenDelegate A delegate that receives token update notifications.
/// @param accessGroup The identifier for a keychain group that the app shares items with; if
/// provided, requires the Keychain Access Groups Entitlement.
/// @return An instance of `AppCheckCore` with the specified token provider.
- (instancetype)initWithServiceName:(NSString *)serviceName
                       resourceName:(NSString *)resourceName
                   appCheckProvider:(id<GACAppCheckProvider>)appCheckProvider
                           settings:(id<GACAppCheckSettingsProtocol>)settings
                      tokenDelegate:(nullable id<GACAppCheckTokenDelegate>)tokenDelegate
                keychainAccessGroup:(nullable NSString *)accessGroup;

@end

NS_ASSUME_NONNULL_END
