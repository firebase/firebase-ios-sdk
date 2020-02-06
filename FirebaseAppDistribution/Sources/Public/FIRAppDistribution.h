// Copyright 2020 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * The Firebase App Distribution API provides methods to annotate and manage
 * fatal and non-fatal reports captured and reported to Firebase App Distribution.
 *
 * By default, Firebase App Distribution is initialized with `[FIRApp configure]`.
 *
 * Note: The App Distribution class cannot be subclassed. If this makes testing difficult,
 * we suggest using a wrapper class or a protocol extension.
 */
NS_SWIFT_NAME(AppDistribution)
@interface FIRAppDistribution : NSObject

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

/**
 * Accesses the singleton App Distribution instance.
 *
 * @return The singleton App Distribution instance.
 */
+ (instancetype)appDistribution NS_SWIFT_NAME(AppDistribution());


@end

NS_ASSUME_NONNULL_END
