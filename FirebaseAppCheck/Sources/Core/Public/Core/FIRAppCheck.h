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

@class FIRApp;
@class FIRAppCheckToken;
@protocol FIRAppCheckProviderFactory;

NS_ASSUME_NONNULL_BEGIN

/// A notification with the specified name is sent to the default notification center
/// (`NotificationCenter.default`) each time a Firebase app check token is refreshed.
/// The user info dictionary contains `kFIRAppCheckTokenNotificationKey` and
/// `kFIRAppCheckAppNameNotificationKey` keys.
FOUNDATION_EXPORT const NSNotificationName
    FIRAppCheckAppCheckTokenDidChangeNotification NS_SWIFT_NAME(AppCheckTokenDidChange);

/// `userInfo` key for the `FirebaseApp.name` in `AppCheckTokenDidChangeNotification`.
FOUNDATION_EXPORT NSString *const kFIRAppCheckTokenNotificationKey NS_SWIFT_NAME(AppCheckTokenNotificationKey);
/// `userInfo` key for the `AppCheckToken` in `AppCheckTokenDidChangeNotification`.
FOUNDATION_EXPORT NSString *const kFIRAppCheckAppNameNotificationKey NS_SWIFT_NAME(AppCheckAppNameNotificationKey);

/// A class used to manage app check tokens for a given Firebase app.
NS_SWIFT_NAME(AppCheck)
@interface FIRAppCheck : NSObject

- (instancetype)init NS_UNAVAILABLE;

/// Returns a default instance of `AppCheck`.
/// @return An instance of `AppCheck` for `FirebaseApp.defaultApp()`.
/// @throw Throws an exception if the default app is not configured yet or required `FirebaseApp`
/// options are missing.
+ (instancetype)appCheck NS_SWIFT_NAME(appCheck());

/// Returns an instance of `AppCheck` for an application.
/// @param firebaseApp A configured `FirebaseApp` instance if exists.
/// @return An instance of `AppCheck` corresponding to the passed application.
/// @throw Throws an exception if required `FirebaseApp` options are missing.
+ (nullable instancetype)appCheckWithApp:(FIRApp *)firebaseApp NS_SWIFT_NAME(appCheck(app:));

/// Sets the `AppCheckProviderFactory` to use to generate
/// `AppCheckDebugProvider` objects.
///
/// An instance of `DeviceCheckProviderFactory` is used by default, but you can
/// also use a custom `AppCheckProviderFactory` implementation or an
/// instance of `AppCheckDebugProviderFactory` to test your app on a simulator
/// on a local machine or a build server.
///
/// NOTE: Make sure to call this method before `FirebaseApp.configure()`. If
/// this method is called after configuring Firebase, the changes will not take
/// effect.
+ (void)setAppCheckProviderFactory:(nullable id<FIRAppCheckProviderFactory>)factory;

/// If this flag is disabled then Firebase app check will not periodically auto-refresh the app
/// check token. The default value of the flag is equal to
/// `FirebaseApp.dataCollectionDefaultEnabled`. To disable the flag by default set
/// `FirebaseAppCheckTokenAutoRefreshEnabled` flag in the app Info.plist to `NO`. Once the flag is
/// set explicitly, the value will be persisted and used as a default value on next app launches.
@property(nonatomic, assign) BOOL isTokenAutoRefreshEnabled;

/// Requests Firebase app check token. This method should *only* be used if you need to authorize
/// requests to a non-Firebase backend. Requests to Firebase backend are authorized automatically if
/// configured.
///
/// If your non-Firebase backend exposes sensitive or expensive endpoints that have low traffic
/// volume, consider protecting it with [Replay
/// Protection](https://firebase.google.com/docs/app-check/custom-resource-backend#replay-protection).
/// In this case, use the ``limitedUseToken(completion:)`` instead to obtain a limited-use token.
/// @param forcingRefresh If `YES`,  a new Firebase app check token is requested and the token
/// cache is ignored. If `NO`, the cached token is used if it exists and has not expired yet. In
/// most cases, `NO` should be used. `YES` should only be used if the server explicitly returns an
/// error, indicating a revoked token.
/// @param handler The completion handler. Includes the app check token if the request succeeds,
/// or an error if the request fails.
- (void)tokenForcingRefresh:(BOOL)forcingRefresh
                 completion:
                     (void (^)(FIRAppCheckToken *_Nullable token, NSError *_Nullable error))handler
    NS_SWIFT_NAME(token(forcingRefresh:completion:));

/// Requests a limited-use Firebase App Check token. This method should be used only if you need to
/// authorize requests to a non-Firebase backend.
///
/// Returns limited-use tokens that are intended for use with your non-Firebase backend endpoints
/// that are protected with [Replay
/// Protection](https://firebase.google.com/docs/app-check/custom-resource-backend#replay-protection).
/// This method does not affect the token generation behavior of the
/// ``tokenForcingRefresh()`` method.
- (void)limitedUseTokenWithCompletion:(void (^)(FIRAppCheckToken *_Nullable token,
                                                NSError *_Nullable error))handler;

@end

NS_ASSUME_NONNULL_END
