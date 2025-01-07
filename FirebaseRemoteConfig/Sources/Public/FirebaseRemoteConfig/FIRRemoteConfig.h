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

#import <Foundation/Foundation.h>

/// The Firebase Remote Config service default namespace, to be used if the API method does not
/// specify a different namespace. Use the default namespace if configuring from the Google Firebase
/// service.
extern NSString *const _Nonnull FIRNamespaceGoogleMobilePlatform NS_SWIFT_NAME(NamespaceGoogleMobilePlatform);

/// Key used to manage throttling in NSError user info when the refreshing of Remote Config
/// parameter values (data) is throttled. The value of this key is the elapsed time since 1970,
/// measured in seconds.
extern NSString *const _Nonnull FIRRemoteConfigThrottledEndTimeInSecondsKey NS_SWIFT_NAME(RemoteConfigThrottledEndTimeInSecondsKey);

/// Completion handler invoked by activate method upon completion.
/// @param error  Error message on failure. Nil if activation was successful.
typedef void (^FIRRemoteConfigActivateCompletion)(NSError *_Nullable error)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");

/// Completion handler invoked upon completion of Remote Config initialization.
///
/// @param initializationError nil if initialization succeeded.
typedef void (^FIRRemoteConfigInitializationCompletion)(NSError *_Nullable initializationError)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");
