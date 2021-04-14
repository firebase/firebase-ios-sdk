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

#import "FIRAppCheckProvider.h"

@class FIRApp;
@protocol FIRAppCheckDebugProviderAPIServiceProtocol;

NS_ASSUME_NONNULL_BEGIN

/// A Firebase app check provider that can exchange a debug token registered in Firebase console to
/// a Firebase app check token. The debug provider is designed to enable testing applications on a
/// simulator or platforms that are not supported yet.
///
/// NOTE: Please make sure the debug provider is not used in applications used by real users.
///
/// WARNING: Keep the Firebase app check debug token in secret. If you accidentally shared one (e.g.
/// committed to a public source repo) make sure to remove it in the Firebase console ASAP.
///
/// To use `AppCheckDebugProvider` on a local simulator:
/// 1. Configure  `AppCheckDebugProviderFactory` before `FirebaseApp.configure()`
/// `AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())`
/// 2. Enable debug logging by adding `-FIRDebugEnabled` launch argument to the app target.
/// 3. Launch the app. A local debug token will be logged when Firebase is configured. For example:
/// "[Firebase/AppCheck][I-FAA001001] Firebase App Check Debug Token:
/// '3BA09C8C-8A0D-4030-ACD5-B96D99DB73F9'".
/// 4. Register the debug token in the Firebase console.
///
/// Once the debug token is registered the debug provider will be able to provide a valid Firebase
/// app check token.
///
/// To use `AppCheckDebugProvider` on a simulator on a build server:
/// 1. Create a new Firebase app check debug token in the Firebase console
/// 2. Add the debug token to the secure storage of your build environment, e.g. see [Encrypted
/// secrets](https://docs.github.com/en/actions/reference/encrypted-secrets) for GitHub Actions,
/// etc.
/// 3. Configure  `AppCheckDebugProviderFactory` before `FirebaseApp.configure()`
/// `AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())`
/// 4. Add an environment variable to the scheme with a name `FIRAAppCheckDebugToken` and value like
/// `$(MY_APP_CHECK_DEBUG_TOKEN)`.
/// 5. Configure the build script to pass the debug token as the environment variable, e.g.:
/// `xcodebuild test -scheme InstallationsExample -workspace InstallationsExample.xcworkspace \
/// MY_APP_CHECK_DEBUG_TOKEN=$(MY_SECRET_ON_CI)`
///
NS_SWIFT_NAME(AppCheckDebugProvider)
@interface FIRAppCheckDebugProvider : NSObject <FIRAppCheckProvider>

- (instancetype)init NS_UNAVAILABLE;

- (nullable instancetype)initWithApp:(FIRApp *)app;

/** Return the locally generated token. */
- (NSString *)localDebugToken;

/** Returns the currently used App Check debug token. The priority:
 *  - `FIRAAppCheckDebugToken` env variable value
 *  - previously generated stored local token
 *  - newly generated random token
 * @return The currently used App Check debug token.
 */
- (NSString *)currentDebugToken;

@end

NS_ASSUME_NONNULL_END
