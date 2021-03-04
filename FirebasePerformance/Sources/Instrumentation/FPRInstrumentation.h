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

/** The key for the network instrumentation group. */
FOUNDATION_EXTERN NSString *const kFPRInstrumentationGroupNetworkKey;

/** The key for the UIKit instrumentation group. */
FOUNDATION_EXTERN NSString *const kFPRInstrumentationGroupUIKitKey;

/** This class manages all automatic instrumentation. */
@interface FPRInstrumentation : NSObject

/** Registers the instrument group.
 *
 *  @param group The group whose instrumentation should be registered.
 *  @return The number of instruments in the group.
 */
- (NSUInteger)registerInstrumentGroup:(NSString *)group;

/** Deregisters the instrument group.
 *
 *  @param group The group whose instrumentation should be deregistered.
 *  @return YES if there are no registered instruments in the group, NO otherwise.
 */
- (BOOL)deregisterInstrumentGroup:(NSString *)group;

@end

NS_ASSUME_NONNULL_END
