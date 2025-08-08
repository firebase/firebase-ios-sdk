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

NS_ASSUME_NONNULL_BEGIN

/// This protocol defines the interface for classes that can create Firebase App Check providers.
NS_SWIFT_NAME(AppCheckProviderFactory)
@protocol FIRAppCheckProviderFactory <NSObject>

/// Creates a new instance of a Firebase App Check provider.
/// @param app An instance of `FirebaseApp` to create the provider for.
/// @return A new instance implementing `AppCheckProvider` protocol.
- (nullable id<FIRAppCheckProvider>)createProviderWithApp:(FIRApp *)app;

@end

NS_ASSUME_NONNULL_END
