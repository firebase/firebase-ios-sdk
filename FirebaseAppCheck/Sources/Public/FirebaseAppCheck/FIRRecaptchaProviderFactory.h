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
#import "FIRAppCheckProviderFactory.h"

NS_ASSUME_NONNULL_BEGIN

/// An implementation of `AppCheckProviderFactory` that creates a new instance of
/// `AppCheckRecaptchaProvider` when requested.
NS_SWIFT_NAME(RecaptchaProviderFactory)
API_AVAILABLE(ios(15.0), visionos(1.0))
API_UNAVAILABLE(macos, tvos, watchos, macCatalyst)
@interface FIRRecaptchaProviderFactory : NSObject <FIRAppCheckProviderFactory>

/// Initializes a factory that will use the site key from Firebase app options.
- (instancetype)init;

@end
NS_ASSUME_NONNULL_END
