/*
 * Copyright 2018 Google
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

#ifndef FIRCoreConfigurable_h
#define FIRCoreConfigurable_h

#import <Foundation/Foundation.h>

@class FIRApp;

NS_ASSUME_NONNULL_BEGIN

/// Provides an interface to set up an SDK once a `FIRApp` is configured.
NS_SWIFT_NAME(CoreConfigurable)
@protocol FIRCoreConfigurable

/// Configure the SDK if needed ahead of time. This method is called when the developer calls
/// `FirebaseApp.configure()`.
+ (void)configureWithApp:(FIRApp *)app;

@end

NS_ASSUME_NONNULL_END

#endif /* FIRCoreConfigurable_h */
