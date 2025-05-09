/*
 * Copyright 2025 Google LLC
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
#import <stdint.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents a BSON timestamp type in Firestore documents.
 */
NS_SWIFT_SENDABLE
NS_SWIFT_NAME(BsonTimestamp)
__attribute__((objc_subclassing_restricted))
@interface FIRBsonTimestamp : NSObject<NSCopying>

/** The underlying unsigned 32-bit integer for seconds */
@property(atomic, readonly) uint32_t seconds;

/** The underlying unsigned 32-bit integer for increment */
@property(atomic, readonly) uint32_t increment;

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

/**
 * Creates a `BsonTimestamp` with the given seconds and increment values.
 * @param seconds  The underlying unsigned 32-bit integer for seconds.
 * @param increment The underlying unsigned 32-bit integer for increment.
 */
- (instancetype)initWithSeconds:(uint32_t)seconds increment:(uint32_t)increment;

/** Returns true if the given object is equal to this, and false otherwise. */
- (BOOL)isEqual:(id)object;

@end

NS_ASSUME_NONNULL_END
