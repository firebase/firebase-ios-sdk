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
 * Represents a binary blob or BSON binary data in Firestore documents.
 */
NS_SWIFT_SENDABLE
NS_SWIFT_NAME(Blob)
__attribute__((objc_subclassing_restricted))
@interface FIRBlob : NSObject<NSCopying>

/** An 8-bit unsigned integer denoting the subtype of the data. Returns 0 for standard Blobs. */
@property(nonatomic, readonly) uint8_t subtype;

/** The binary data. */
@property(nonatomic, copy, readonly) NSData *bytes;

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

/**
 * Creates a standard `Blob` with the given data.
 * @param bytes The binary data.
 */
+ (instancetype)blobWithBytes:(NSData *)bytes NS_SWIFT_NAME(init(bytes:));

/**
 * Creates a BSON Binary type `Blob` with subtype 0.
 * @param bytes The binary data.
 */
+ (instancetype)blobWithBSONBinary:(NSData *)bytes NS_SWIFT_NAME(init(bsonBinary:));

/**
 * Creates a BSON Binary type `Blob` with the specified subtype.
 * @param bytes The binary data.
 * @param subtype An 8-bit unsigned integer denoting the subtype of the data (must be [0, 255]).
 */
+ (instancetype)blobWithBSONBinary:(NSData *)bytes
                           subtype:(uint8_t)subtype NS_SWIFT_NAME(init(bsonBinary:subtype:));

/** Returns true if the given object is equal to this, and false otherwise. */
- (BOOL)isEqual:(nullable id)object;

/** Compares this Blob to another Blob. */
- (NSComparisonResult)compare:(FIRBlob *)other;

@end

NS_ASSUME_NONNULL_END
