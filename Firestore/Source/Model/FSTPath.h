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

#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * FSTPath represents a path sequence in the Firestore database. It is composed of an ordered
 * sequence of string segments.
 *
 * ## Subclassing Notes
 *
 * FSTPath itself is an abstract class that must be specialized by subclasses. Subclasses should
 * implement constructors for common string-based representations of the path and also override
 * -canonicalString which converts back to the canonical string-based representation of the path.
 */
@interface FSTPath <SelfType> : NSObject

/** Returns the path segment of the given index. */
- (NSString *)segmentAtIndex:(int)index;
- (id)objectAtIndexedSubscript:(int)index;

- (BOOL)isEqual:(id)path;
- (NSComparisonResult)compare:(SelfType)other;

/**
 * Returns a new path whose segments are the current path's plus one more.
 *
 * @param segment The new segment to concatenate to the path.
 * @return A new path with this path's segment plus the new one.
 */
- (instancetype)pathByAppendingSegment:(NSString *)segment;

/**
 * Returns a new path whose segments are the current path's plus another's.
 *
 * @param path The new path whose segments should be concatenated to the path.
 * @return A new path with this path's segment plus the new ones.
 */
- (instancetype)pathByAppendingPath:(SelfType)path;

/** Returns a new path whose segments are the same as this one's minus the first one. */
- (instancetype)pathByRemovingFirstSegment;

/** Returns a new path whose segments are the same as this one's minus the first `count`. */
- (instancetype)pathByRemovingFirstSegments:(int)count;

/** Returns a new path whose segments are the same as this one's minus the last one. */
- (instancetype)pathByRemovingLastSegment;

/** Convenience method for getting the first segment of this path. */
- (NSString *)firstSegment;

/** Convenience method for getting the last segment of this path. */
- (NSString *)lastSegment;

/** Returns true if this path is a prefix of the given path. */
- (BOOL)isPrefixOfPath:(SelfType)other;

/** Returns a standardized string representation of this path. */
- (NSString *)canonicalString;

/** The number of segments in the path. */
@property(nonatomic, readonly) int length;

/** True if the path is empty. */
@property(nonatomic, readonly, getter=isEmpty) BOOL empty;

@end

/** A dot-separated path for navigating sub-objects within a document. */
@class FSTFieldPath;

@interface FSTFieldPath : FSTPath <FSTFieldPath *>

/**
 * Creates and returns a new path with the given segments. The array of segments is not copied, so
 * one should not mutate the array once it is passed in here.
 *
 * @param segments The underlying array of segments for the path.
 * @return A new instance of FSTPath.
 */
+ (instancetype)pathWithSegments:(NSArray<NSString *> *)segments;

/**
 * Creates and returns a new path from the server formatted field-path string, where path segments
 * are separated by a dot "." and optionally encoded using backticks.
 *
 * @param fieldPath A dot-separated string representing the path.
 */
+ (instancetype)pathWithServerFormat:(NSString *)fieldPath;

/** Returns a field path that represents a document key. */
+ (instancetype)keyFieldPath;

/** Returns a field path that represents an empty path. */
+ (instancetype)emptyPath;

/** Returns YES if this is the `FSTFieldPath.keyFieldPath` field path. */
- (BOOL)isKeyFieldPath;

/** Creates and returns a new path from C++ FieldPath.
 *
 * @param fieldPath A C++ FieldPath.
 */
+ (instancetype)fieldPathWithCPPFieldPath:(const firebase::firestore::model::FieldPath &)fieldPath;

/**
 * Creates and returns a new C++ FieldPath.
 */
- (firebase::firestore::model::FieldPath)toCPPFieldPath;

@end

/** A slash-separated path for navigating resources (documents and collections) within Firestore. */
@class FSTResourcePath;

@interface FSTResourcePath : FSTPath <FSTResourcePath *>

/**
 * Creates and returns a new path with the given segments. The array of segments is not copied, so
 * one should not mutate the array once it is passed in here.
 *
 * @param segments The underlying array of segments for the path.
 * @return A new instance of FSTPath.
 */
+ (instancetype)pathWithSegments:(NSArray<NSString *> *)segments;

/**
 * Creates and returns a new path from the given resource-path string, where the path segments are
 * separated by a slash "/".
 *
 * @param resourcePath A slash-separated string representing the path.
 */
+ (instancetype)pathWithString:(NSString *)resourcePath;

/** Creates and returns a new path from C++ ResourcePath.
 *
 * @param resourcePath A C++ ResourcePath.
 */
+ (instancetype)resourcePathWithCPPResourcePath:
    (const firebase::firestore::model::ResourcePath &)resourcePath;

/**
 * Creates and returns a new C++ ResourcePath.
 */
- (firebase::firestore::model::ResourcePath)toCPPResourcePath;
@end

NS_ASSUME_NONNULL_END
