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

#include <initializer_list>
#include <string>

#include "Firestore/core/src/firebase/firestore/model/resource_path.h"

NS_ASSUME_NONNULL_BEGIN

/** FSTDocumentKey represents the location of a document in the Firestore database. */
@interface FSTDocumentKey : NSObject <NSCopying>

/**
 * Creates and returns a new document key with the given path.
 *
 * @param path The path to the document.
 * @return A new instance of FSTDocumentKey.
 */
+ (instancetype)keyWithPath:(firebase::firestore::model::ResourcePath)path;
/**
 * Creates and returns a new document key with a path with the given segments.
 *
 * @param segments The segments of the path to the document.
 * @return A new instance of FSTDocumentKey.
 */
+ (instancetype)keyWithSegments:(std::initializer_list<std::string>)segments;
/**
 * Creates and returns a new document key from the given resource path string.
 *
 * @param resourcePath The slash-separated segments of the resource's path.
 * @return A new instance of FSTDocumentKey.
 */
+ (instancetype)keyWithPathString:(NSString *)resourcePath;

/** Returns true iff the given path is a path to a document. */
+ (BOOL)isDocumentKey:(const firebase::firestore::model::ResourcePath &)path;
- (BOOL)isEqualToKey:(FSTDocumentKey *)other;
- (NSComparisonResult)compare:(FSTDocumentKey *)other;

/** The path to the document. */
- (const firebase::firestore::model::ResourcePath &)path;

@end

extern const NSComparator FSTDocumentKeyComparator;

/** The field path string that represents the document's key. */
extern NSString *const kDocumentKeyPath;

NS_ASSUME_NONNULL_END
