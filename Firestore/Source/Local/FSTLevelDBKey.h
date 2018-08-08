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

/** A key to a singleton row storing the version of the schema. */
@interface FSTLevelDBVersionKey : NSObject

/** Returns the key pointing to the singleton row storing the schema version. */
+ (std::string)key;

@end

/** A key in the mutations table. */
@interface FSTLevelDBMutationKey : NSObject

/** Creates a key prefix that points just before the first key in the table. */
+ (std::string)keyPrefix;

/** Creates a key prefix that points just before the first key for the given userID. */
+ (std::string)keyPrefixWithUserID:(Firestore::StringView)userID;

/** Creates a complete key that points to a specific userID and batchID. */
+ (std::string)keyWithUserID:(Firestore::StringView)userID batchID:(FSTBatchID)batchID;

/**
 * Decodes the given complete key, storing the decoded values as properties of the receiver.
 *
 * @return YES if the key successfully decoded, NO otherwise. If NO is returned, the properties of
 *     the receiver are in an undefined state until the next call to -decodeKey:.
 */
- (BOOL)decodeKey:(Firestore::StringView)key;

/** The user that owns the mutation batches. */
@property(nonatomic, assign, readonly) const std::string &userID;

/** The batchID of the batch. */
@property(nonatomic, assign, readonly) FSTBatchID batchID;

@end

/**
 * A key in the document mutations index, which stores the batches in which documents are mutated.
 */
@interface FSTLevelDBDocumentMutationKey : NSObject

/** Creates a key prefix that points just before the first key in the table. */
+ (std::string)keyPrefix;

/** Creates a key prefix that points just before the first key for the given userID. */
+ (std::string)keyPrefixWithUserID:(Firestore::StringView)userID;

/**
 * Creates a key prefix that points just before the first key for the userID and resource path.
 *
 * Note that this uses a ResourcePath rather than an FSTDocumentKey in order to allow prefix
 * scans over a collection. However a naive scan over those results isn't useful since it would
 * match both immediate children of the collection and any subcollections.
 */
+ (std::string)keyPrefixWithUserID:(Firestore::StringView)userID
                      resourcePath:(const firebase::firestore::model::ResourcePath &)resourcePath;

/** Creates a complete key that points to a specific userID, document key, and batchID. */
+ (std::string)keyWithUserID:(Firestore::StringView)userID
                 documentKey:(FSTDocumentKey *)documentKey
                     batchID:(FSTBatchID)batchID;

/**
 * Decodes the given complete key, storing the decoded values as properties of the receiver.
 *
 * @return YES if the key successfully decoded, NO otherwise. If NO is returned, the properties of
 *     the receiver are in an undefined state until the next call to -decodeKey:.
 */
- (BOOL)decodeKey:(Firestore::StringView)key;

/** The user that owns the mutation batches. */
@property(nonatomic, assign, readonly) const std::string &userID;

/** The path to the document, as encoded in the key. */
@property(nonatomic, strong, readonly, nullable) FSTDocumentKey *documentKey;

/** The batchID in which the document participates. */
@property(nonatomic, assign, readonly) FSTBatchID batchID;

@end

/**
 * A key in the mutation_queues table.
 *
 * Note that where mutation_queues contains one row about each queue, mutations contains the actual
 * mutation batches themselves.
 */
@interface FSTLevelDBMutationQueueKey : NSObject

/** Creates a key prefix that points just before the first key in the table. */
+ (std::string)keyPrefix;

/** Creates a complete key that points to a specific mutation queue entry for the given userID. */
+ (std::string)keyWithUserID:(Firestore::StringView)userID;

/**
 * Decodes the given complete key, storing the decoded values as properties of the receiver.
 *
 * @return YES if the key successfully decoded, NO otherwise. If NO is returned, the properties of
 *     the receiver are in an undefined state until the next call to -decodeKey:.
 */
- (BOOL)decodeKey:(Firestore::StringView)key;

@property(nonatomic, assign, readonly) const std::string &userID;

@end

/** A key in the target globals table, a record of global values across all targets. */
@interface FSTLevelDBTargetGlobalKey : NSObject

/** Creates a key that points to the single target global row. */
+ (std::string)key;

/**
 * Decodes the contents of a target global key, essentially just verifying that the key has the
 * correct table name.
 */
- (BOOL)decodeKey:(Firestore::StringView)key;

@end

/** A key in the targets table. */
@interface FSTLevelDBTargetKey : NSObject

/** Creates a key prefix that points just before the first key in the table. */
+ (std::string)keyPrefix;

/** Creates a complete key that points to a specific target, by targetID. */
+ (std::string)keyWithTargetID:(FSTTargetID)targetID;

/**
 * Decodes the contents of a target key into properties on this instance.
 *
 * @return YES if the key successfully decoded, NO otherwise. If NO is returned, the properties of
 *     the receiver are in an undefined state until the next call to -decodeKey:.
 */
- (BOOL)decodeKey:(Firestore::StringView)key;

/** The targetID identifying a target. */
@property(nonatomic, assign, readonly) FSTTargetID targetID;

@end

/**
 * A key in the query targets table, an index of canonicalIDs to the targets they may match. This
 * is not a unique mapping because canonicalID does not promise a unique name for all possible
 * queries.
 */
@interface FSTLevelDBQueryTargetKey : NSObject

/**
 * Creates a key that contains just the query targets table prefix and points just before the
 * first key.
 */
+ (std::string)keyPrefix;

/** Creates a key that points to the first query-target association for a canonicalID. */
+ (std::string)keyPrefixWithCanonicalID:(Firestore::StringView)canonicalID;

/** Creates a key that points to a specific query-target entry. */
+ (std::string)keyWithCanonicalID:(Firestore::StringView)canonicalID targetID:(FSTTargetID)targetID;

/** Decodes the contents of a query target key into properties on this instance. */
- (BOOL)decodeKey:(Firestore::StringView)key;

/** The canonicalID derived from the query. */
@property(nonatomic, assign, readonly) const std::string &canonicalID;

/** The targetID identifying a target. */
@property(nonatomic, assign, readonly) FSTTargetID targetID;

@end

/**
 * A key in the target documents table, an index of targetIDs to the documents they contain.
 */
@interface FSTLevelDBTargetDocumentKey : NSObject

/**
 * Creates a key that contains just the target documents table prefix and points just before the
 * first key.
 */
+ (std::string)keyPrefix;

/** Creates a key that points to the first target-document association for a targetID. */
+ (std::string)keyPrefixWithTargetID:(FSTTargetID)targetID;

/** Creates a key that points to a specific target-document entry. */
+ (std::string)keyWithTargetID:(FSTTargetID)targetID documentKey:(FSTDocumentKey *)documentKey;

/** Decodes the contents of a target document key into properties on this instance. */
- (BOOL)decodeKey:(Firestore::StringView)key;

/** The targetID identifying a target. */
@property(nonatomic, assign, readonly) FSTTargetID targetID;

/** The path to the document, as encoded in the key. */
@property(nonatomic, strong, readonly, nullable) FSTDocumentKey *documentKey;

@end

BOOL FSTTargetIDIsSentinel(FSTTargetID targetId);

/**
 * A key in the document targets table, an index from documents to the targets that contain them.
 */
@interface FSTLevelDBDocumentTargetKey : NSObject

/**
 * Creates a key that contains just the document targets table prefix and points just before the
 * first key.
 */
+ (std::string)keyPrefix;

/** Creates a key that points to the first document-target association for document. */
+ (std::string)keyPrefixWithResourcePath:
    (const firebase::firestore::model::ResourcePath &)resourcePath;

/** Creates a key that points to a specific document-target entry. */
+ (std::string)keyWithDocumentKey:(FSTDocumentKey *)documentKey targetID:(FSTTargetID)targetID;

+ (std::string)sentinelKeyWithDocumentKey:(FSTDocumentKey *)documentKey;

/** Decodes the contents of a document target key into properties on this instance. */
- (BOOL)decodeKey:(Firestore::StringView)key;

/** The targetID identifying a target. */
@property(nonatomic, assign, readonly) FSTTargetID targetID;

/** The path to the document, as encoded in the key. */
@property(nonatomic, strong, readonly, nullable) FSTDocumentKey *documentKey;

@end

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
