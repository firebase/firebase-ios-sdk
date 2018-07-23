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

#import "GULRuntimeClassDiff.h"
#import "GULRuntimeDiff.h"

NS_ASSUME_NONNULL_BEGIN

/** A helper class that enables the snapshotting and diffing of ObjC runtime state. */
@interface GULRuntimeStateHelper : NSObject

/** Captures the current state of the entire runtime and returns the snapshot number.
 *
 *  @return The snapshot number corresponding to this capture.
 */
+ (NSUInteger)captureRuntimeState;

/** Captures the current state of the runtime for the provided classes.
 *
 *  @param classes The classes whose state should be snapshotted.
 *  @return The snapshot number corresponding to this capture.
 */
+ (NSUInteger)captureRuntimeStateOfClasses:(NSSet<Class> *)classes;

/** Prints the diff between two snapshot numbers.
 *
 *  @param firstSnapshot The first runtime snapshot, as provided by captureRuntimeState.
 *  @param secondSnapshot The runtime snapshot sometime after firstSnapshot.
 *  @return An instance of GULRuntimeDiff that contains the diff information.
 */
+ (GULRuntimeDiff *)diffBetween:(NSUInteger)firstSnapshot secondSnapshot:(NSUInteger)secondSnapshot;

@end

NS_ASSUME_NONNULL_END
