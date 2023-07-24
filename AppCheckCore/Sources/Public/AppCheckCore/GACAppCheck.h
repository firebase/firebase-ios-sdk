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

@class GACAppCheckToken;
@protocol GACAppCheckProvider;
@protocol GACAppCheckSettingsProtocol;
@protocol GACAppCheckTokenDelegate;
@protocol GACAppCheckTokenProtocol;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(AppCheckCoreTokenHandler)
typedef void (^GACAppCheckTokenHandler)(id<GACAppCheckTokenProtocol> _Nullable token,
                                        NSError *_Nullable error);

NS_SWIFT_NAME(AppCheckCoreProtocol) @protocol GACAppCheckProtocol

/// Requests Firebase app check token.
///
/// @param forcingRefresh If `YES`,  a new Firebase app check token is requested and the token
/// cache is ignored. If `NO`, the cached token is used if it exists and has not expired yet. In
/// most cases, `NO` should be used. `YES` should only be used if the server explicitly returns an
/// error, indicating a revoked token.
/// @param handler The completion handler. Includes the app check token if the request succeeds,
/// or an error if the request fails.
- (void)getTokenForcingRefresh:(BOOL)forcingRefresh
                    completion:(GACAppCheckTokenHandler)handler
    NS_SWIFT_NAME(token(forcingRefresh:completion:));

/// Retrieve a new limited-use App Check token
///
/// This method does not affect the token generation behavior of the
/// ``tokenForcingRefresh()`` method.
- (void)getLimitedUseTokenWithCompletion:(GACAppCheckTokenHandler)handler;

@end

/// A class used to manage App Check tokens for a given resource.
NS_SWIFT_NAME(AppCheckCore)
@interface GACAppCheck : NSObject <GACAppCheckProtocol>

- (instancetype)init NS_UNAVAILABLE;

/// Returns an instance of `AppCheck` for an application.
/// @param appCheckProvider  An object that provides App Check tokens.
/// @param settings An object that provides App Check settings.
/// @param resourceName The name of the resource protected by App Check; for a Firebase App this is
/// "projects/{project_id}/apps/{app_id}".
/// @param tokenDelegate A delegate that receives token update notifications.
/// @param accessGroup The identifier for a keychain group that the app shares items with; if
/// provided, requires the Keychain Access Groups Entitlement.
/// @return An instance of `AppCheckCore` with the specified token provider.
- (instancetype)initWithInstanceName:(NSString *)instanceName
                    appCheckProvider:(id<GACAppCheckProvider>)appCheckProvider
                            settings:(id<GACAppCheckSettingsProtocol>)settings
                        resourceName:(NSString *)resourceName
                       tokenDelegate:(nullable id<GACAppCheckTokenDelegate>)tokenDelegate
                 keychainAccessGroup:(nullable NSString *)accessGroup;

@end

NS_ASSUME_NONNULL_END
