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

// NOTE: For Swift compatibility, please keep this header Objective-C only.
//       Swift cannot interact with any C++ definitions.
#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "Firestore/Example/Tests/Util/XCTestCase+Await.h"

#import "FIRFirestoreSource.h"

@class FIRApp;
@class FIRAggregateQuery;
@class FIRAggregateQuerySnapshot;
@class FIRCollectionReference;
@class FIRDocumentSnapshot;
@class FIRDocumentReference;
@class FIRQuerySnapshot;
@class FIRFirestore;
@class FIRFirestoreSettings;
@class FIRQuery;
@class FIRWriteBatch;
@class FSTEventAccumulator;
@class FIRTransaction;

NS_ASSUME_NONNULL_BEGIN

#if __cplusplus
extern "C" {
#endif

@interface FSTIntegrationTestCase : XCTestCase

/** Returns the default Firestore project ID for testing. */
+ (NSString *)projectID;

/** Returns the default Firestore database ID for testing. */
+ (NSString *)databaseID;

+ (bool)isRunningAgainstEmulator;

/** Returns a FirestoreSettings configured to use either hexa or the emulator. */
+ (FIRFirestoreSettings *)settings;

/** Returns a new Firestore connected to the "test-db" project. */
- (FIRFirestore *)firestore;

/** Returns a new Firestore connected to the project with the given projectID. */
- (FIRFirestore *)firestoreWithProjectID:(NSString *)projectID;

/** Triggers a user change with given user id. */
- (void)triggerUserChangeWithUid:(NSString *)uid;

/**
 * Returns a new Firestore connected to the project with the given app.
 */
- (FIRFirestore *)firestoreWithApp:(FIRApp *)app;

/** Synchronously terminates the given firestore. */
- (void)terminateFirestore:(FIRFirestore *)firestore;

/** Synchronously deletes the given FIRapp. */
- (void)deleteApp:(FIRApp *)app;

- (NSString *)documentPath;

- (FIRDocumentReference *)documentRef;

- (FIRCollectionReference *)collectionRef;

- (FIRCollectionReference *)collectionRefWithDocuments:
    (NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)documents;

- (void)writeAllDocuments:(NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)documents
             toCollection:(FIRCollectionReference *)collection;

- (void)readerAndWriterOnDocumentRef:(void (^)(FIRDocumentReference *readerRef,
                                               FIRDocumentReference *writerRef))action;

- (FIRDocumentSnapshot *)readDocumentForRef:(FIRDocumentReference *)ref;

- (FIRDocumentSnapshot *)readDocumentForRef:(FIRDocumentReference *)ref
                                     source:(FIRFirestoreSource)source;

- (FIRQuerySnapshot *)readDocumentSetForRef:(FIRQuery *)query;

- (FIRQuerySnapshot *)readDocumentSetForRef:(FIRQuery *)query source:(FIRFirestoreSource)source;

- (FIRDocumentSnapshot *)readSnapshotForRef:(FIRDocumentReference *)query
                              requireOnline:(BOOL)online;

- (FIRAggregateQuerySnapshot *)readSnapshotForAggregate:(FIRAggregateQuery *)query;

- (void)writeDocumentRef:(FIRDocumentReference *)ref data:(NSDictionary<NSString *, id> *)data;

- (void)updateDocumentRef:(FIRDocumentReference *)ref data:(NSDictionary<NSString *, id> *)data;

- (void)deleteDocumentRef:(FIRDocumentReference *)ref;

- (FIRDocumentReference *)addDocumentRef:(FIRCollectionReference *)ref
                                    data:(NSDictionary<NSString *, id> *)data;

- (void)runTransaction:(FIRFirestore *)db
                 block:(id _Nullable (^)(FIRTransaction *, NSError **error))block
            completion:(nullable void (^)(id _Nullable result, NSError *_Nullable error))completion;

- (void)mergeDocumentRef:(FIRDocumentReference *)ref data:(NSDictionary<NSString *, id> *)data;

- (void)mergeDocumentRef:(FIRDocumentReference *)ref
                    data:(NSDictionary<NSString *, id> *)data
                  fields:(NSArray<id> *)fields;

- (void)commitWriteBatch:(FIRWriteBatch *)batch;

- (void)disableNetwork;

- (void)enableNetwork;

- (void)checkOnlineAndOfflineQuery:(FIRQuery *)query matchesResult:(NSArray *)expectedDocs;

/**
 * "Blocks" the current thread/run loop until the block returns YES.
 * Should only be called on the main thread.
 * The block is invoked frequently and in a loop (every couple of milliseconds) to ensure fast
 * test progress and make sure actions to be run on main thread are not blocked by this method.
 */
- (void)waitUntil:(BOOL (^)())predicate;

@property(nonatomic, strong) FIRFirestore *db;
@property(nonatomic, strong) FSTEventAccumulator *eventAccumulator;
@property(nonatomic, strong) NSMutableArray<FIRFirestore *> *firestores;
@end

/** Converts the FIRQuerySnapshot to an NSArray containing the data of the documents in order. */
NSArray<NSDictionary<NSString *, id> *> *FIRQuerySnapshotGetData(FIRQuerySnapshot *docs);

/** Converts the FIRQuerySnapshot to an NSArray containing the document IDs in order. */
NSArray<NSString *> *FIRQuerySnapshotGetIDs(FIRQuerySnapshot *docs);

/** Converts the FIRQuerySnapshot to an NSArray containing an NSArray containing the doc change data
 * in order of { type, doc title, doc data }. */
NSArray<NSArray<id> *> *FIRQuerySnapshotGetDocChangesData(FIRQuerySnapshot *docs);

/** Gets the FIRDocumentReference objects from a FIRQuerySnapshot and returns them. */
NSArray<FIRDocumentReference *> *FIRDocumentReferenceArrayFromQuerySnapshot(FIRQuerySnapshot *);

#if __cplusplus
}  // extern "C"
#endif

NS_ASSUME_NONNULL_END
