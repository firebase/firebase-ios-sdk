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

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents a BSON ObjectId type in Firestore documents.
 */
NS_SWIFT_SENDABLE
NS_SWIFT_NAME(BsonObjectId)
__attribute__((objc_subclassing_restricted))
@interface FIRBsonObjectId : NSObject<NSCopying>

/** The 24-character hex string representation of the ObjectId. */
@property(atomic, copy, readonly) NSString *value;

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

/**
 * Creates a `BsonObjectId` constructed with the given value.
 * @param value The 24-character hex string representation of the ObjectId.
 */
- (instancetype)initWithValue:(nonnull NSString *)value NS_SWIFT_NAME(init(_:));

/** Returns true if the given object is equal to this, and false otherwise. */
- (BOOL)isEqual:(id)object;

@end

NS_ASSUME_NONNULL_END
