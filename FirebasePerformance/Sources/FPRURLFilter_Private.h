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

/** This extension should only be used for testing. */
@interface FPRURLFilter ()

/** Set to YES to disable the retrieval of allowed domains from the Info.plist. This property
 *  should only be used in tests in order to prevent the need for mocks.
 */
@property(nonatomic) BOOL disablePlist;

/** List of domains that are allowed for instrumenting network requests.
 */
@property(nonatomic, readonly, nullable) NSArray *allowlistDomains;

/** NSBundle that is used for referring to allowed domains.
 */
@property(nonatomic, readonly, nullable) NSBundle *mainBundle;

/** Custom initializer to be used in unit tests for taking in a custom bundle and return an instance
 * of FPRURLFilter.
 *
 * @param bundle Custom bundle to use for initialization.
 * @return Instance of FPRURLFilter.
 */
- (instancetype)initWithBundle:(NSBundle *)bundle;

@end

NS_ASSUME_NONNULL_END
