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

@class GDLLogEvent;

NS_ASSUME_NONNULL_BEGIN

/** Manages the storage of logs. This class is thread-safe. */
@interface GDLLogStorage : NSObject <NSSecureCoding>

/** Creates and/or returns the storage singleton.
 *
 * @return The storage singleton.
 */
+ (instancetype)sharedInstance;

/** Stores log.extensionBytes into a shared on-device folder and tracks the log via its hash and
 * logTarget properties.
 *
 * @note The log param is expected to be deallocated during this method.
 *
 * @param log The log to store.
 */
- (void)storeLog:(GDLLogEvent *)log;

/** Removes a set of log fields specified by their filenames.
 *
 * @param logHashes The set of log files to remove.
 * @param logTarget The log target the log files correspond to.
 */
- (void)removeLogs:(NSSet<NSNumber *> *)logHashes logTarget:(NSNumber *)logTarget;

/** Converts a set of log hashes to a set of log files.
 *
 * @param logHashes A set of log hashes to get the files of.
 * @return A set of equivalent length, containing all the filenames corresponding to the hashes.
 */
- (NSSet<NSURL *> *)logHashesToFiles:(NSSet<NSNumber *> *)logHashes;

@end

NS_ASSUME_NONNULL_END
