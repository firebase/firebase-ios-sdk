/*
 * Copyright 2024 Google LLC
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
 * Represents a vector type in Firestore documents.
 */
NS_SWIFT_SENDABLE
NS_SWIFT_NAME(VectorValue)
@interface FIRVectorValue : NSObject

/** Returns a copy of the raw number array that represents the vector. */
@property(atomic, readonly) NSArray<NSNumber *> *array NS_REFINED_FOR_SWIFT;

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

/**
 * Creates a `VectorValue` constructed with a copy of the given array of NSNumbrers.
 * @param array An array of NSNumbers that represents a vector.
 */
- (instancetype)initWithArray:(NSArray<NSNumber *> *)array NS_REFINED_FOR_SWIFT;

@end

NS_ASSUME_NONNULL_END
