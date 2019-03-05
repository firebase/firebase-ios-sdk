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

#import <Foundation/Foundation.h>

@class GDTEvent;

NS_ASSUME_NONNULL_BEGIN

/** Manages the storage of events. This class is thread-safe. */
@interface GDTStorage : NSObject <NSSecureCoding>

/** Creates and/or returns the storage singleton.
 *
 * @return The storage singleton.
 */
+ (instancetype)sharedInstance;

/** Stores event.dataObjectTransportBytes into a shared on-device folder and tracks the event via
 * its hash and target properties.
 *
 * @note The event param is expected to be deallocated during this method.
 *
 * @param event The event to store.
 */
- (void)storeEvent:(GDTEvent *)event;

/** Removes a set of event from storage specified by their hash.
 *
 * @param eventHashes The set of event hashes to remove.
 * @param target The upload target the event files correspond to.
 */
- (void)removeEvents:(NSSet<NSNumber *> *)eventHashes target:(NSNumber *)target;

/** Converts a set of event hashes to a set of event files.
 *
 * @param eventHashes A set of event hashes to get the files of.
 * @return A set of equivalent length, containing all the filenames corresponding to the hashes.
 */
- (NSDictionary<NSNumber *, NSURL *> *)eventHashesToFiles:(NSSet<NSNumber *> *)eventHashes;

@end

NS_ASSUME_NONNULL_END
