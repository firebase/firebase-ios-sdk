/*
 * Copyright 2026 Google LLC
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

NS_ASSUME_NONNULL_BEGIN

/// Reads App Check debug tokens provisioned by the Firebase CLI
/// (`firebase appcheck:debugtokens:create`) into the config store file on the developer's host
/// machine (`~/.config/configstore/firebase-appcheck.json`).
///
/// Only apps running in a Simulator (iOS, tvOS, watchOS, or visionOS) can reach the host file
/// system, using the `SIMULATOR_HOST_HOME` environment variable that the Simulator sets to the
/// host user's home directory. On devices, macOS, and Mac Catalyst the lookup is compiled out and
/// always returns `nil`.
@interface FIRAppCheckDebugTokenConfigStore : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/// The path of the config store file, relative to the host user's home directory.
@property(class, nonatomic, readonly) NSString *relativePath;

/// Returns the debug token provisioned for the given app, or `nil` when not running in a
/// Simulator, when `SIMULATOR_HOST_HOME` is unset, or when the config store file is missing,
/// unreadable, or contains no token for the app.
///
/// @param googleAppID The Google App ID of the `FirebaseApp` to look up.
+ (nullable NSString *)debugTokenForGoogleAppID:(NSString *)googleAppID;

/// Variant of `+debugTokenForGoogleAppID:` that reads `SIMULATOR_HOST_HOME` from the given
/// environment rather than from the current process. Exposed for testing.
+ (nullable NSString *)debugTokenForGoogleAppID:(NSString *)googleAppID
                                    environment:(NSDictionary<NSString *, NSString *> *)environment;

@end

NS_ASSUME_NONNULL_END
