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

@protocol FIRAppCheckProviderFactory;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(AppCheck)
@interface FIRAppCheck : NSObject

- (instancetype)init NS_UNAVAILABLE;

/// Set an instance of a Firebase app check provider factory. An instance of
/// `DeviceCheckProviderFactory` is used by default. An instance of `AppCheckDebugProvider` can be
/// used to test on a simulator on a local machine or a build server.
/// NOTE: Make sure to call the method before `FirebaseApp.configure()`. If the method is called
/// after configuring Firebase, the changes will not be applied.
+ (void)setAppCheckProviderFactory:(nullable id<FIRAppCheckProviderFactory>)factory;

@end

NS_ASSUME_NONNULL_END
