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

#include <string>

#import "Firestore/Source/Core/FSTTypes.h"
#import "Firestore/Source/Local/StringView.h"

#include "Firestore/core/src/firebase/firestore/model/resource_path.h"

@class FSTDocumentKey;

NS_ASSUME_NONNULL_BEGIN

// All leveldb logical tables should have their keys structures described in this file.
//
// mutations:
//   - tableName: string = "mutation"
//   - userID: string
//   - batchID: FSTBatchID
//
// document_mutations:
//   - tableName: string = "document_mutation"
//   - userID: string
//   - path: ResourcePath
//   - batchID: FSTBatchID
//
// mutation_queues:
//   - tableName: string = "mutation_queue"
//   - userID: string
//
// targets:
//   - tableName: string = "target"
//   - targetId: FSTTargetID
//
// target_globals:
//   - tableName: string = "target_global"
//
// query_targets:
//   - tableName: string = "query_target"
//   - canonicalID: string
//   - targetId: FSTTargetID
//
// target_documents:
//   - tableName: string = "target_document"
//   - targetID: FSTTargetID
//   - path: ResourcePath
//
// document_targets:
//   - tableName: string = "document_target"
//   - path: ResourcePath
//   - targetID: FSTTargetID
//
// remote_documents:
//   - tableName: string = "remote_document"
//   - path: ResourcePath

/** A key in the remote documents table. */
@interface FSTLevelDBRemoteDocumentKey : NSObject

/**
 * Creates a key that contains just the remote documents table prefix and points just before the
 * first remote document key.
 */
+ (std::string)keyPrefix;

/**
 * Creates a complete key that points to a specific document. The documentKey must have an even
 * number of path segments.
 */
+ (std::string)keyWithDocumentKey:(FSTDocumentKey *)key;

/**
 * Creates a key prefix that contains a part of a document path. Odd numbers of segments create a
 * collection key prefix, while an even number of segments create a document key prefix. Note that
 * a document key prefix will match the document itself and any documents that exist in its
 * subcollections.
 */
+ (std::string)keyPrefixWithResourcePath:
    (const firebase::firestore::model::ResourcePath &)resourcePath;

/**
 * Decodes the contents of a remote document key into properties on this instance. This can only
 * decode complete document paths (i.e. the result of +keyWithDocumentKey:).
 *
 * @return YES if the key successfully decoded, NO otherwise. If NO is returned, the properties of
 *     the receiver are in an undefined state until the next call to -decodeKey:.
 */
- (BOOL)decodeKey:(Firestore::StringView)key;

/** The path to the document, as encoded in the key. */
@property(nonatomic, strong, readonly, nullable) FSTDocumentKey *documentKey;

@end

NS_ASSUME_NONNULL_END
