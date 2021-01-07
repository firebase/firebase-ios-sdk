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

#import "FirebasePerformance/Sources/AppActivity/FPRSessionManager.h"

NS_ASSUME_NONNULL_BEGIN

/** This extension should only be used for testing. */
@interface FPRSessionManager ()

/** The current active session managed by the session manager. Modifiable for unit tests */
@property(nonatomic, nullable, readwrite) FPRSessionDetails *sessionDetails;

/**
 * Checks if the currently active session is beyond maximum allowed time. If so renew the session,
 * else no-op.
 */
- (void)renewSessionIdIfRunningTooLong;

@end

NS_ASSUME_NONNULL_END
