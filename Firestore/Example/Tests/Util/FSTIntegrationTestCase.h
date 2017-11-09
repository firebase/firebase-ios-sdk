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
#import <XCTest/XCTest.h>

#import "XCTestCase+Await.h"

@class FIRCollectionReference;
@class FIRDocumentSnapshot;
@class FIRDocumentReference;
@class FIRQuerySnapshot;
@class FIRFirestore;
@class FIRFirestoreSettings;
@class FIRQuery;
@class FSTEventAccumulator;

NS_ASSUME_NONNULL_BEGIN

#if __cplusplus
extern "C" {
#endif

@interface FSTIntegrationTestCase : XCTestCase

/** Returns the default Firestore project ID for testing. */
+ (NSString *)projectID;

/** Returns a FirestoreSettings configured to use either hexa or the emulator. */
+ (FIRFirestoreSettings *)settings;

/** Returns a new Firestore connected to the "test-db" project. */
- (FIRFirestore *)firestore;

/** Returns a new Firestore connected to the project with the given projectID. */
- (FIRFirestore *)firestoreWithProjectID:(NSString *)projectID;

/** Synchronously shuts down the given firestore. */
- (void)shutdownFirestore:(FIRFirestore *)firestore;

- (NSString *)documentPath;

- (FIRDocumentReference *)documentRef;

- (FIRCollectionReference *)collectionRef;

- (FIRCollectionReference *)collectionRefWithDocuments:
    (NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)documents;

- (void)waitForIdleFirestore:(FIRFirestore *)firestore;

- (void)writeAllDocuments:(NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)documents
             toCollection:(FIRCollectionReference *)collection;

- (void)readerAndWriterOnDocumentRef:(void (^)(NSString *path,
                                               FIRDocumentReference *readerRef,
                                               FIRDocumentReference *writerRef))action;

- (FIRDocumentSnapshot *)readDocumentForRef:(FIRDocumentReference *)ref;

- (FIRQuerySnapshot *)readDocumentSetForRef:(FIRQuery *)query;

- (FIRDocumentSnapshot *)readSnapshotForRef:(FIRDocumentReference *)query
                              requireOnline:(BOOL)online;

- (void)writeDocumentRef:(FIRDocumentReference *)ref data:(NSDictionary<NSString *, id> *)data;

- (void)updateDocumentRef:(FIRDocumentReference *)ref data:(NSDictionary<NSString *, id> *)data;

- (void)deleteDocumentRef:(FIRDocumentReference *)ref;

/**
 * "Blocks" the current thread/run loop until the block returns YES.
 * Should only be called on the main thread.
 * The block is invoked frequently and in a loop (every couple of milliseconds) to ensure fast
 * test progress and make sure actions to be run on main thread are not blocked by this method.
 */
- (void)waitUntil:(BOOL (^)())predicate;

@property(nonatomic, strong) FIRFirestore *db;
@property(nonatomic, strong) FSTEventAccumulator *eventAccumulator;
@end

/** Converts the FIRQuerySnapshot to an NSArray containing the data of the documents in order. */
NSArray<NSDictionary<NSString *, id> *> *FIRQuerySnapshotGetData(FIRQuerySnapshot *docs);

/** Converts the FIRQuerySnapshot to an NSArray containing the document IDs in order. */
NSArray<NSString *> *FIRQuerySnapshotGetIDs(FIRQuerySnapshot *docs);

#if __cplusplus
}  // extern "C"
#endif

NS_ASSUME_NONNULL_END
