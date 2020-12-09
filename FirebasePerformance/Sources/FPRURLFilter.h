// Copyright 2020 Google LLC
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

/** Allows the filtering of URLs based on a allowlist specified in the Info.plist. */
@interface FPRURLFilter : NSObject

/** Returns a singleton URL filterer.
 *
 *  @return The singleton instance. */
+ (instancetype)sharedInstance;

/** Default initializer is disabled.
 */
- (instancetype)init NS_UNAVAILABLE;

/** Checks the allowlist and denylist, and returns a YES or NO depending on their state.
 *
 *  @note The current implementation is very naive. The denylist is only set by the SDK, and these
 *      URLs will not be allowed, even if we explicitly allow them.
 *
 *  @param URL The URL string to check.
 *  @return YES if the URL should be instrumented, NO otherwise.
 */
- (BOOL)shouldInstrumentURL:(NSString *)URL;

@end

NS_ASSUME_NONNULL_END
