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
 * Represents a BSON Binary Data type in Firestore documents.
 */
NS_SWIFT_SENDABLE
NS_SWIFT_NAME(BSONBinaryData)
__attribute__((objc_subclassing_restricted))
@interface FIRBSONBinaryData : NSObject<NSCopying>

/** An 8-bit unsigned integer denoting the subtype of the data. */
@property(nonatomic, readonly) uint8_t subtype;

/** The binary data. */
@property(nonatomic, copy, readonly) NSData *data;

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

/**
 * Creates a `BSONBinaryData` constructed with the given subtype and data.
 * @param subtype An 8-bit unsigned integer denoting the subtype of the data.
 * @param data The binary data.
 */
- (instancetype)initWithSubtype:(uint8_t)subtype data:(nonnull NSData *)data;

/** Returns true if the given object is equal to this, and false otherwise. */
- (BOOL)isEqual:(id)object;

@end

NS_ASSUME_NONNULL_END
