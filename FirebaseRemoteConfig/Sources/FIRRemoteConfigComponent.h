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

#import <FirebaseCore/FIRLibrary.h>

@class FIRApp;
@class FIRRemoteConfig;

NS_ASSUME_NONNULL_BEGIN

/// Provides and creates instances of Remote Config based on the namespace provided. Used in the
/// interop registration process to keep track of RC instances for each `FIRApp` instance.
@protocol FIRRemoteConfigProvider

/// Cached instances of Remote Config objects.
@property(nonatomic, strong) NSMutableDictionary<NSString *, FIRRemoteConfig *> *instances;

/// Default method for retrieving a Remote Config instance, or creating one if it doesn't exist.
- (FIRRemoteConfig *)remoteConfigForNamespace:(NSString *)remoteConfigNamespace;

@end

/// A concrete implementation for FIRRemoteConfigInterop to create Remote Config instances and
/// register with Core's component system.
@interface FIRRemoteConfigComponent : NSObject <FIRRemoteConfigProvider, FIRLibrary>

/// The FIRApp that instances will be set up with.
@property(nonatomic, weak, readonly) FIRApp *app;

/// Cached instances of Remote Config objects.
@property(nonatomic, strong) NSMutableDictionary<NSString *, FIRRemoteConfig *> *instances;

/// Default method for retrieving a Remote Config instance, or creating one if it doesn't exist.
- (FIRRemoteConfig *)remoteConfigForNamespace:(NSString *)remoteConfigNamespace;

/// Default initializer.
- (instancetype)initWithApp:(FIRApp *)app NS_DESIGNATED_INITIALIZER;

- (instancetype)init __attribute__((unavailable("Use `initWithApp:`.")));

@end

NS_ASSUME_NONNULL_END
