/*
 * Copyright 2018 Google LLC
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

@class GULRuntimeClassDiff;

NS_ASSUME_NONNULL_BEGIN

/** This class is able to capture the runtime state of a given class. */
@interface GULRuntimeClassSnapshot : NSObject

- (instancetype)init NS_UNAVAILABLE;

/** Instantiates an instance of this class with the given class.
 *
 *  @param aClass The class that will be snapshot.
 *  @return An instance of this class.
 */
- (instancetype)initWithClass:(Class)aClass NS_DESIGNATED_INITIALIZER;

/** Captures the runtime state of this class. */
- (void)capture;

/** Calculates the diff between snapshots and returns a diff object populated with information.
 *
 *  @param otherClassSnapshot The other snapshot to compare it to. It's assumed that the
 *      otherClassSnapshot was created after the caller.
 *  @return A diff object representing the diff between the two snapshots.
 */
- (GULRuntimeClassDiff *)diff:(GULRuntimeClassSnapshot *)otherClassSnapshot;

@end

NS_ASSUME_NONNULL_END
