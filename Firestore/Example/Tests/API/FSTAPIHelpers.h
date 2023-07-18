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

@class FIRCollectionReference;
@class FIRDocumentReference;
@class FIRDocumentSnapshot;
@class FIRFirestore;
@class FIRQuerySnapshot;

/** Allow tests to just use an int literal for versions. */
typedef int64_t FSTTestSnapshotVersion;

NS_ASSUME_NONNULL_BEGIN

#if __cplusplus
extern "C" {
#endif

/** A convenience method for creating dummy singleton FIRFirestore for tests. */
FIRFirestore *FSTTestFirestore();

/** A convenience method for creating a doc snapshot for tests. */
FIRDocumentSnapshot *FSTTestDocSnapshot(const char *path,
                                        FSTTestSnapshotVersion version,
                                        NSDictionary<NSString *, id> *_Nullable data,
                                        BOOL hasMutations,
                                        BOOL fromCache);

/** A convenience method for creating a collection reference from a path string. */
FIRCollectionReference *FSTTestCollectionRef(const char *path);

/** A convenience method for creating a document reference from a path string. */
FIRDocumentReference *FSTTestDocRef(const char *path);

/**
 * A convenience method for creating a particular query snapshot for tests.
 *
 * @param path To be used in constructing the query.
 * @param oldDocs Provides the prior set of documents in the QuerySnapshot. Each dictionary entry
 * maps to a document, with the key being the document id, and the value being the document
 * contents.
 * @param docsToAdd Specifies data to be added into the query snapshot as of now. Each dictionary
 * entry maps to a document, with the key being the document id, and the value being the document
 * contents.
 * @param hasPendingWrites Whether the query snapshot has pending writes to the server.
 * @param fromCache Whether the query snapshot is cache result.
 * @param hasCachedResults Whether the query snapshot has results in the cache.
 * @return A query snapshot that consists of both sets of documents.
 */
FIRQuerySnapshot *FSTTestQuerySnapshot(
    const char *path,
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *oldDocs,
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *docsToAdd,
    BOOL hasPendingWrites,
    BOOL fromCache,
    BOOL hasCachedResults);

#if __cplusplus
}  // extern "C"
#endif

@interface FSTNSExceptionUtil : NSObject

+ (BOOL)testForException:(void (^)(void))methodToTry
          reasonContains:(nonnull NSString *)message
    NS_SWIFT_NAME(testForException(_:reasonContains:));

@end

NS_ASSUME_NONNULL_END
