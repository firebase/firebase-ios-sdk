/*
 * Copyright 2017 Google
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

NS_ASSUME_NONNULL_BEGIN

@class FIRTimestamp;

/**
 * A version of a document in Firestore. This corresponds to the version timestamp, such as
 * update_time or read_time.
 */
@interface FSTSnapshotVersion : NSObject <NSCopying>

/** Creates a new version that is smaller than all other versions. */
+ (instancetype)noVersion;

/** Creates a new version representing the given timestamp. */
+ (instancetype)versionWithTimestamp:(FIRTimestamp *)timestamp;

- (instancetype)init NS_UNAVAILABLE;

- (NSComparisonResult)compare:(FSTSnapshotVersion *)other;

@property(nonatomic, strong, readonly) FIRTimestamp *timestamp;

@end

NS_ASSUME_NONNULL_END
