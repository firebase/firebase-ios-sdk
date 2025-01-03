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

#import <FirebaseRemoteConfig/FIRRemoteConfig.h>

@class FIROptions;
@class RCNConfigContent;
@class RCNConfigDBManager;
@class RCNConfigFetch;
@protocol FIRAnalyticsInterop;

NS_ASSUME_NONNULL_BEGIN

@class RCNConfigSettings;

@interface FIRRemoteConfig () {
  NSString *_FIRNamespace;
}

/// Config settings are custom settings.
@property(nonatomic, readwrite, strong, nonnull) RCNConfigFetch *configFetch;

/// Returns the FIRRemoteConfig instance for your namespace and for the default Firebase App.
/// This singleton object contains the complete set of Remote Config parameter values available to
/// the app, including the Active Config and Default Config.. This object also caches values fetched
/// from the Remote Config Server until they are copied to the Active Config by calling
/// activateFetched. When you fetch values from the Remote Config Server using the default Firebase
/// namespace service, you should use this class method to create a shared instance of the
/// FIRRemoteConfig object to ensure that your app will function properly with the Remote Config
/// Server and the Firebase service. This API is used internally by 2P teams.
+ (FIRRemoteConfig *)remoteConfigWithFIRNamespace:(NSString *)remoteConfigNamespace
    NS_SWIFT_NAME(remoteConfig(FIRNamespace:));

@end

NS_ASSUME_NONNULL_END
