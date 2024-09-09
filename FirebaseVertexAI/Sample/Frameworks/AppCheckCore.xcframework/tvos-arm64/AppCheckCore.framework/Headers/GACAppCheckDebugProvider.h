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

#import "GACAppCheckProvider.h"

NS_ASSUME_NONNULL_BEGIN

/// An App Check provider that can exchange a debug token registered in the Firebase console for an
/// App Check token. The debug provider is designed to enable testing applications on a simulator or
/// in a test environment.
///
/// NOTE: Do not use the debug provider in production applications used by real users.
///
/// WARNING: Keep the App Check debug token secret. If you accidentally share one (e.g., commit it
/// to a public source repository), remove it in the Firebase console ASAP.
///
/// To use `AppCheckCoreDebugProvider` on a local simulator:
/// 1. Launch the app. A local debug token will be logged when the `AppCheckCoreDebugProvider` is
///    instantiated. For example:
///    "[AppCheckCore][I-GAC004001] App Check debug token: 'AB12C3D4-56EF-789G-01H2-IJ234567K8L9'."
/// 2. Register the debug token in the Firebase console.
///
/// Once the debug token is registered in the Firebase console, the debug provider will be able to
/// provide a valid App Check token.
///
/// To use `AppCheckCoreDebugProvider` in a Continuous Integration (CI) environment:
/// 1. Create a new App Check debug token in the Firebase console.
/// 2. Add the debug token to the secure storage of your build environment. E.g., see
///    [Encrypted secrets](https://docs.github.com/en/actions/reference/encrypted-secrets) for
///    GitHub Actions.
/// 4. Add an environment variable to the scheme with a name `AppCheckDebugToken` and a value like
///    `$(MY_APP_CHECK_DEBUG_TOKEN)`.
/// 5. Configure the build script to pass the debug token as in environment variable, e.g.:
///    `xcodebuild test -scheme InstallationsExample -workspace InstallationsExample.xcworkspace \
///      MY_APP_CHECK_DEBUG_TOKEN=$(MY_SECRET_ON_CI)`
NS_SWIFT_NAME(AppCheckCoreDebugProvider)
@interface GACAppCheckDebugProvider : NSObject <GACAppCheckProvider>

- (instancetype)init NS_UNAVAILABLE;

/// The default initializer.
/// @param serviceName A unique identifier to differentiate storage keys corresponding to the same
/// `resourceName`; may be a Firebase App Name or an SDK name.
/// @param resourceName The name of the resource protected by App Check; for a Firebase App this is
/// "projects/{project_id}/apps/{app_id}".
/// @param baseURL The base URL for the App Check service; defaults to
/// `https://firebaseappcheck.googleapis.com/v1` if nil.
/// @param APIKey The Google Cloud Platform API key.
/// @param requestHooks Hooks that will be invoked on requests through this service.
/// @return An instance of `AppCheckCoreDebugProvider`.
- (instancetype)initWithServiceName:(NSString *)serviceName
                       resourceName:(NSString *)resourceName
                            baseURL:(nullable NSString *)baseURL
                             APIKey:(NSString *)APIKey
                       requestHooks:(nullable NSArray<GACAppCheckAPIRequestHook> *)requestHooks;

/// Returns the locally generated token.
- (NSString *)localDebugToken;

/// Returns the currently used App Check debug token.
///
/// The priority of the token used is:
/// 1. The `AppCheckDebugToken` environment variable value
/// 2. The `FIRAAppCheckDebugToken` environment variable value
/// 3. A previously generated token, stored locally on the device
/// 4. A newly generated random token. The generated token will be stored locally for future use
///
/// @return The currently used App Check debug token.
- (NSString *)currentDebugToken;

@end

NS_ASSUME_NONNULL_END
