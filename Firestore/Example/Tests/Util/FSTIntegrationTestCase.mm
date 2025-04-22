/*
 * Copyright 2017 Google LLC
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

#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"

#import <FirebaseFirestore/FIRCollectionReference.h>
#import <FirebaseFirestore/FIRDocumentChange.h>
#import <FirebaseFirestore/FIRDocumentReference.h>
#import <FirebaseFirestore/FIRDocumentSnapshot.h>
#import <FirebaseFirestore/FIRFirestore.h>
#import <FirebaseFirestore/FIRFirestoreSettings.h>
#import <FirebaseFirestore/FIRQuerySnapshot.h>
#import <FirebaseFirestore/FIRSnapshotMetadata.h>
#import <FirebaseFirestore/FIRTransaction.h>
#import <FirebaseFirestore/FIRWriteBatch.h>

#include <exception>
#include <memory>
#include <string>
#include <utility>

#import "FirebaseCore/Extension/FIRAppInternal.h"
#import "FirebaseCore/Extension/FIRLogger.h"
#import "FirebaseCore/Sources/Public/FirebaseCore/FIRLoggerLevel.h"
#import "FirebaseCore/Sources/Public/FirebaseCore/FIROptions.h"
#import "Firestore/Example/Tests/Util/FIRFirestore+Testing.h"
#import "Firestore/Example/Tests/Util/FSTEventAccumulator.h"
#import "Firestore/Source/API/FIRAggregateQuery+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"

#include "Firestore/core/src/credentials/credentials_provider.h"
#include "Firestore/core/src/credentials/empty_credentials_provider.h"
#include "Firestore/core/src/credentials/user.h"
#include "Firestore/core/src/local/leveldb_opener.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/remote/firebase_metadata_provider_apple.h"
#include "Firestore/core/src/remote/grpc_connection.h"
#include "Firestore/core/src/util/async_queue.h"
#include "Firestore/core/src/util/autoid.h"
#include "Firestore/core/src/util/filesystem.h"
#include "Firestore/core/src/util/path.h"
#include "Firestore/core/src/util/string_apple.h"
#include "Firestore/core/test/unit/testutil/app_testing.h"
#include "Firestore/core/test/unit/testutil/async_testing.h"
#include "Firestore/core/test/unit/testutil/status_testing.h"
#include "absl/memory/memory.h"

using firebase::firestore::core::DatabaseInfo;
using firebase::firestore::credentials::CredentialChangeListener;
using firebase::firestore::credentials::EmptyAppCheckCredentialsProvider;
using firebase::firestore::credentials::EmptyAuthCredentialsProvider;
using firebase::firestore::credentials::User;
using firebase::firestore::local::LevelDbOpener;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::remote::FirebaseMetadataProviderApple;
using firebase::firestore::testutil::AppForUnitTesting;
using firebase::firestore::testutil::AsyncQueueForTesting;
using firebase::firestore::util::AsyncQueue;
using firebase::firestore::util::CreateAutoId;
using firebase::firestore::util::Filesystem;
using firebase::firestore::util::MakeString;
using firebase::firestore::util::Path;
using firebase::firestore::util::Status;
using firebase::firestore::util::StatusOr;

NS_ASSUME_NONNULL_BEGIN

/**
 * Firestore databases can be subject to a ~30s "cold start" delay if they have not been used
 * recently, so before any tests run we "prime" the backend.
 */
static const double kPrimingTimeout = 45.0;

static NSString *defaultProjectId;
static NSString *defaultDatabaseId = @"(default)";
static FIRFirestoreSettings *defaultSettings;

static bool runningAgainstEmulator = false;

// Behaves the same as `EmptyCredentialsProvider` except it can also trigger a user
// change.
class FakeAuthCredentialsProvider : public EmptyAuthCredentialsProvider {
 public:
  void SetCredentialChangeListener(CredentialChangeListener<User> changeListener) override {
    if (changeListener) {
      listener_ = std::move(changeListener);
      listener_(User::Unauthenticated());
    }
  }

  void ChangeUser(NSString *new_id) {
    if (listener_) {
      listener_(firebase::firestore::credentials::User::FromUid(new_id));
    }
  }

 private:
  CredentialChangeListener<User> listener_;
};

@implementation FSTIntegrationTestCase {
  NSMutableArray<FIRFirestore *> *_firestores;
  std::shared_ptr<EmptyAppCheckCredentialsProvider> _fakeAppCheckCredentialsProvider;
  std::shared_ptr<FakeAuthCredentialsProvider> _fakeAuthCredentialsProvider;
}

- (void)setUp {
  [super setUp];

  LoadXCTestCaseAwait();

  _fakeAppCheckCredentialsProvider = std::make_shared<EmptyAppCheckCredentialsProvider>();
  _fakeAuthCredentialsProvider = std::make_shared<FakeAuthCredentialsProvider>();

  [self clearPersistenceOnce];
  [self primeBackend];

  _firestores = [NSMutableArray array];
  self.db = [self firestore];
  self.eventAccumulator = [FSTEventAccumulator accumulatorForTest:self];
}

- (void)tearDown {
  @try {
    for (FIRFirestore *firestore in _firestores) {
      [self terminateFirestore:firestore];
    }
  } @finally {
    _firestores = nil;
    [super tearDown];
  }
}

/**
 * Clears persistence, but only the first time. This ensures that each test
 * run is isolated from the last test run, but doesn't allow tests to interfere
 * with each other.
 */
- (void)clearPersistenceOnce {
  auto *fs = Filesystem::Default();
  static bool clearedPersistence = false;

  @synchronized([FSTIntegrationTestCase class]) {
    if (clearedPersistence) return;
    DatabaseInfo dbInfo;
    LevelDbOpener opener(dbInfo);
    StatusOr<Path> maybeLevelDBDir = opener.FirestoreAppDataDir();
    ASSERT_OK(maybeLevelDBDir.status());
    Path levelDBDir = std::move(maybeLevelDBDir).ValueOrDie();

    Status status = fs->RecursivelyRemove(levelDBDir);
    ASSERT_OK(status);

    clearedPersistence = true;
  }
}

- (FIRFirestore *)firestore {
  return [self firestoreWithProjectID:[FSTIntegrationTestCase projectID]];
}

/**
 * Figures out what kind of testing environment we're using, and sets up testing defaults to make
 * that work.
 *
 * Several configurations are supported:
 *   * Mobile Harness, running periocally against prod and nightly, using live SSL certs
 *   * Firestore emulator, running on localhost, with SSL disabled
 *
 * See Firestore/README.md for detailed setup instructions or comments below for which specific
 * values trigger which configurations.
 */
+ (void)setUpDefaults {
  if (defaultSettings) return;

  defaultSettings = [[FIRFirestoreSettings alloc] init];

  // Setup database id to use.
  NSString *databaseId = [[NSProcessInfo processInfo] environment][@"TARGET_DATABASE_ID"];
  if (databaseId) {
    defaultDatabaseId = databaseId;
  }

  // Check for a MobileHarness configuration, running against nightly or prod, which have live
  // SSL certs.
  NSString *project = [[NSProcessInfo processInfo] environment][@"PROJECT_ID"];
  NSString *targetBackend = [[NSProcessInfo processInfo] environment][@"TARGET_BACKEND"];
  NSString *host;
  if (targetBackend) {
    if ([targetBackend isEqualToString:@"emulator"]) {
      [self setUpEmulatorDefault];
      return;
    } else if ([targetBackend isEqualToString:@"qa"]) {
      host = @"staging-firestore.sandbox.googleapis.com";
    } else if ([targetBackend isEqualToString:@"nightly"]) {
      host = @"test-firestore.sandbox.googleapis.com";
    } else if ([targetBackend isEqualToString:@"prod"]) {
      host = @"firestore.googleapis.com";
    } else {
      @throw [[NSException alloc]
          initWithName:@"InvalidArgumentError"
                reason:[NSString stringWithFormat:
                                     @"Unexpected TARGET_BACKEND environment variable \"%@\"",
                                     targetBackend]
              userInfo:nil];
    }
  } else {
    host = [[NSProcessInfo processInfo] environment][@"DATASTORE_HOST"];
  }

  if (project && host) {
    defaultProjectId = project;
    defaultSettings.host = host;

    NSLog(@"Integration tests running against %@/(%@:%@)", defaultSettings.host, defaultProjectId,
          defaultDatabaseId);
    return;
  }

  // Check for configuration of a prod project via GoogleServices-Info.plist.
  FIROptions *options = [FIROptions defaultOptions];
  if (options && ![options.projectID isEqualToString:@"abc-xyz-123"]) {
    defaultProjectId = options.projectID;
    if (host) {
      // Allow access to nightly or other hosts via this mechanism too.
      defaultSettings.host = host;
    }

    NSLog(@"Integration tests running against %@/(%@:%@)", defaultSettings.host, defaultProjectId,
          defaultDatabaseId);
    return;
  }

  // Otherwise fall back on assuming the emulator or localhost.
  [self setUpEmulatorDefault];
}

+ (void)setUpEmulatorDefault {
  defaultProjectId = @"test-db";

  defaultSettings.host = @"localhost:8080";
  defaultSettings.sslEnabled = false;
  runningAgainstEmulator = true;

  NSLog(@"Integration tests running against the emulator at %@/%@", defaultSettings.host,
        defaultProjectId);
}

+ (NSString *)projectID {
  if (!defaultProjectId) {
    [self setUpDefaults];
  }
  return defaultProjectId;
}

+ (NSString *)databaseID {
  if (!defaultDatabaseId) {
    return @"(default)";
  }
  return defaultDatabaseId;
}

+ (bool)isRunningAgainstEmulator {
  // The only way to determine whether or not we're running against the emulator is to figure out
  // which testing environment we're using.  Essentially `setUpDefaults` determines
  // `runningAgainstEmulator` as a side effect.
  if (!defaultProjectId) {
    [self setUpDefaults];
  }
  return runningAgainstEmulator;
}

+ (FIRFirestoreSettings *)settings {
  [self setUpDefaults];
  return defaultSettings;
}

- (FIRFirestore *)firestoreWithProjectID:(NSString *)projectID {
  FIRApp *app = AppForUnitTesting(MakeString(projectID));
  return [self firestoreWithApp:app];
}

- (FIRFirestore *)firestoreWithApp:(FIRApp *)app {
  NSString *persistenceKey = [NSString stringWithFormat:@"db%lu", (unsigned long)_firestores.count];

  FIRSetLoggerLevel(FIRLoggerLevelDebug);

  std::string projectID = MakeString(app.options.projectID);
  std::string databaseID = MakeString(defaultDatabaseId);
  FIRFirestore *firestore =
      [[FIRFirestore alloc] initWithDatabaseID:DatabaseId(projectID, databaseID)
                                persistenceKey:MakeString(persistenceKey)
                       authCredentialsProvider:_fakeAuthCredentialsProvider
                   appCheckCredentialsProvider:_fakeAppCheckCredentialsProvider
                                   workerQueue:AsyncQueueForTesting()
                      firebaseMetadataProvider:absl::make_unique<FirebaseMetadataProviderApple>(app)
                                   firebaseApp:app
                              instanceRegistry:nil];

  firestore.settings = [FSTIntegrationTestCase settings];
  [_firestores addObject:firestore];
  return firestore;
}

- (void)triggerUserChangeWithUid:(NSString *)uid {
  _fakeAuthCredentialsProvider->ChangeUser(uid);
}

- (void)primeBackend {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [FSTIntegrationTestCase setUpDefaults];
    if (runningAgainstEmulator) {
      // Priming not required against the emulator.
      return;
    }

    FIRFirestore *db = [self firestore];
    XCTestExpectation *watchInitialized =
        [self expectationWithDescription:@"Prime backend: Watch initialized"];
    __block XCTestExpectation *watchUpdateReceived;
    FIRDocumentReference *docRef = [db documentWithPath:[self documentPath]];
    id<FIRListenerRegistration> listenerRegistration =
        [docRef addSnapshotListener:^(FIRDocumentSnapshot *snapshot, NSError *) {
          if ([snapshot[@"value"] isEqual:@"done"]) {
            [watchUpdateReceived fulfill];
          } else {
            [watchInitialized fulfill];
          }
        }];

    // Wait for watch to initialize and deliver first event.
    [self awaitExpectation:watchInitialized];

    watchUpdateReceived = [self expectationWithDescription:@"Prime backend: Watch update received"];

    // Use a transaction to perform a write without triggering any local events.
    [docRef.firestore
        runTransactionWithBlock:^id(FIRTransaction *transaction, NSError **) {
          [transaction setData:@{@"value" : @"done"} forDocument:docRef];
          return nil;
        }
                     completion:^(id, NSError *){
                     }];

    // Wait to see the write on the watch stream.
    [self waitForExpectationsWithTimeout:kPrimingTimeout
                                 handler:^(NSError *_Nullable expectationError) {
                                   if (expectationError) {
                                     XCTFail(@"Error waiting for prime backend: %@",
                                             expectationError);
                                   }
                                 }];

    [listenerRegistration remove];

    [self terminateFirestore:db];
  });
}

- (void)terminateFirestore:(FIRFirestore *)firestore {
  XCTestExpectation *expectation = [self expectationWithDescription:@"shutdown"];
  [firestore terminateWithCompletion:[self completionForExpectation:expectation]];
  [self awaitExpectation:expectation];
}

- (void)deleteApp:(FIRApp *)app {
  XCTestExpectation *expectation = [self expectationWithDescription:@"deleteApp"];
  [app deleteApp:^(BOOL completion) {
    XCTAssertTrue(completion);
    [expectation fulfill];
  }];
  [self awaitExpectation:expectation];
}

- (NSString *)documentPath {
  std::string autoId = CreateAutoId();
  return [NSString stringWithFormat:@"test-collection/%s", autoId.c_str()];
}

- (FIRDocumentReference *)documentRef {
  return [self.db documentWithPath:[self documentPath]];
}

- (FIRCollectionReference *)collectionRef {
  std::string autoId = CreateAutoId();
  NSString *collectionName = [NSString stringWithFormat:@"test-collection-%s", autoId.c_str()];
  return [self.db collectionWithPath:collectionName];
}

- (FIRCollectionReference *)collectionRefWithDocuments:
    (NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)documents {
  FIRCollectionReference *collection = [self collectionRef];
  // Use a different instance to write the documents
  [self writeAllDocuments:documents
             toCollection:[[self firestore] collectionWithPath:collection.path]];
  return collection;
}

- (void)writeAllDocuments:(NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)documents
             toCollection:(FIRCollectionReference *)collection {
  NSMutableArray<XCTestExpectation *> *commits = [[NSMutableArray alloc] init];
  __block FIRWriteBatch *writeBatch = nil;
  __block int writeBatchSize = 0;

  [documents enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary<NSString *, id> *value,
                                                 BOOL *) {
    if (writeBatch == nil) {
      writeBatch = [collection.firestore batch];
    }

    [writeBatch setData:value forDocument:[collection documentWithPath:key]];
    writeBatchSize++;

    // Write batches are capped at 500 writes. Use 400 just to be safe.
    if (writeBatchSize == 400) {
      XCTestExpectation *commitExpectation = [self expectationWithDescription:@"WriteBatch commit"];
      [writeBatch commitWithCompletion:^(NSError *_Nullable error) {
        [commitExpectation fulfill];
        XCTAssertNil(error, @"WriteBatch commit failed: %@", error);
      }];
      [commits addObject:commitExpectation];
      writeBatch = nil;
      writeBatchSize = 0;
    }
  }];

  if (writeBatch != nil) {
    XCTestExpectation *commitExpectation = [self expectationWithDescription:@"WriteBatch commit"];
    [writeBatch commitWithCompletion:^(NSError *_Nullable error) {
      [commitExpectation fulfill];
      XCTAssertNil(error, @"WriteBatch commit failed: %@", error);
    }];
    [commits addObject:commitExpectation];
  }

  for (XCTestExpectation *commitExpectation in commits) {
    [self awaitExpectation:commitExpectation];
  }
}

- (void)readerAndWriterOnDocumentRef:(void (^)(FIRDocumentReference *readerRef,
                                               FIRDocumentReference *writerRef))action {
  FIRFirestore *reader = self.db;  // for clarity
  FIRFirestore *writer = [self firestore];

  NSString *path = [self documentPath];
  FIRDocumentReference *readerRef = [reader documentWithPath:path];
  FIRDocumentReference *writerRef = [writer documentWithPath:path];
  action(readerRef, writerRef);
}

- (FIRDocumentSnapshot *)readDocumentForRef:(FIRDocumentReference *)ref {
  return [self readDocumentForRef:ref source:FIRFirestoreSourceDefault];
}

- (FIRDocumentSnapshot *)readDocumentForRef:(FIRDocumentReference *)ref
                                     source:(FIRFirestoreSource)source {
  __block FIRDocumentSnapshot *result;

  XCTestExpectation *expectation = [self expectationWithDescription:@"getData"];
  [ref getDocumentWithSource:source
                  completion:^(FIRDocumentSnapshot *doc, NSError *_Nullable error) {
                    XCTAssertNil(error);
                    result = doc;
                    [expectation fulfill];
                  }];
  [self awaitExpectation:expectation];

  return result;
}

- (FIRQuerySnapshot *)readDocumentSetForRef:(FIRQuery *)query {
  return [self readDocumentSetForRef:query source:FIRFirestoreSourceDefault];
}

- (FIRQuerySnapshot *)readDocumentSetForRef:(FIRQuery *)query source:(FIRFirestoreSource)source {
  if (query == nil) {
    XCTFail("Trying to read data from a nil query");
  }
  __block FIRQuerySnapshot *result;

  XCTestExpectation *expectation = [self expectationWithDescription:@"getData"];
  [query getDocumentsWithSource:source
                     completion:^(FIRQuerySnapshot *documentSet, NSError *error) {
                       XCTAssertNil(error);
                       result = documentSet;
                       [expectation fulfill];
                     }];
  [self awaitExpectation:expectation];

  return result;
}

- (FIRDocumentSnapshot *)readSnapshotForRef:(FIRDocumentReference *)ref
                              requireOnline:(BOOL)requireOnline {
  __block FIRDocumentSnapshot *result;

  XCTestExpectation *expectation = [self expectationWithDescription:@"listener"];
  id<FIRListenerRegistration> listener = [ref
      addSnapshotListenerWithIncludeMetadataChanges:YES
                                           listener:^(FIRDocumentSnapshot *snapshot,
                                                      NSError *error) {
                                             XCTAssertNil(error);
                                             if (!requireOnline || !snapshot.metadata.fromCache) {
                                               result = snapshot;
                                               [expectation fulfill];
                                             }
                                           }];

  [self awaitExpectation:expectation];
  [listener remove];

  return result;
}

- (FIRAggregateQuerySnapshot *)readSnapshotForAggregate:(FIRAggregateQuery *)query {
  __block FIRAggregateQuerySnapshot *result;
  XCTestExpectation *expectation = [self expectationWithDescription:@"aggregate result"];

  [query aggregationWithSource:FIRAggregateSourceServer
                    completion:^(FIRAggregateQuerySnapshot *snapshot, NSError *error) {
                      XCTAssertNil(error);
                      result = snapshot;
                      [expectation fulfill];
                    }];

  [self awaitExpectation:expectation];

  return result;
}

- (void)writeDocumentRef:(FIRDocumentReference *)ref data:(NSDictionary<NSString *, id> *)data {
  XCTestExpectation *expectation = [self expectationWithDescription:@"setData"];
  [ref setData:data completion:[self completionForExpectation:expectation]];
  [self awaitExpectation:expectation];
}

- (void)updateDocumentRef:(FIRDocumentReference *)ref data:(NSDictionary<id, id> *)data {
  XCTestExpectation *expectation = [self expectationWithDescription:@"updateData"];
  [ref updateData:data completion:[self completionForExpectation:expectation]];
  [self awaitExpectation:expectation];
}

- (void)deleteDocumentRef:(FIRDocumentReference *)ref {
  XCTestExpectation *expectation = [self expectationWithDescription:@"deleteDocument"];
  [ref deleteDocumentWithCompletion:[self completionForExpectation:expectation]];
  [self awaitExpectation:expectation];
}

- (FIRDocumentReference *)addDocumentRef:(FIRCollectionReference *)ref
                                    data:(NSDictionary<NSString *, id> *)data {
  XCTestExpectation *expectation = [self expectationWithDescription:@"addDocument"];
  FIRDocumentReference *doc = [ref addDocumentWithData:data
                                            completion:[self completionForExpectation:expectation]];
  [self awaitExpectation:expectation];
  return doc;
}

- (void)runTransaction:(FIRFirestore *)db
                 block:(id _Nullable (^)(FIRTransaction *, NSError **error))block
            completion:
                (nullable void (^)(id _Nullable result, NSError *_Nullable error))completion {
  XCTestExpectation *expectation = [self expectationWithDescription:@"runTransaction"];
  [db runTransactionWithOptions:nil
                          block:block
                     completion:^(id _Nullable result, NSError *_Nullable error) {
                       if (completion) {
                         completion(result, error);
                       }
                       [expectation fulfill];
                     }];
  [self awaitExpectation:expectation];
}

- (void)mergeDocumentRef:(FIRDocumentReference *)ref data:(NSDictionary<NSString *, id> *)data {
  XCTestExpectation *expectation = [self expectationWithDescription:@"setDataWithMerge"];
  [ref setData:data merge:YES completion:[self completionForExpectation:expectation]];
  [self awaitExpectation:expectation];
}

- (void)mergeDocumentRef:(FIRDocumentReference *)ref
                    data:(NSDictionary<NSString *, id> *)data
                  fields:(NSArray<id> *)fields {
  XCTestExpectation *expectation = [self expectationWithDescription:@"setDataWithMerge"];
  [ref setData:data mergeFields:fields completion:[self completionForExpectation:expectation]];
  [self awaitExpectation:expectation];
}

- (void)commitWriteBatch:(FIRWriteBatch *)batch {
  XCTestExpectation *expectation = [self expectationWithDescription:@"WriteBatch commit"];
  [batch commitWithCompletion:^(NSError *_Nullable error) {
    [expectation fulfill];
    XCTAssertNil(error, @"WriteBatch commit should have succeeded, but it failed: %@", error);
  }];
  [self awaitExpectation:expectation];
}

- (void)disableNetwork {
  XCTestExpectation *expectation = [self expectationWithDescription:@"disableNetwork"];
  [self.db disableNetworkWithCompletion:[self completionForExpectation:expectation]];
  [self awaitExpectation:expectation];
}

- (void)enableNetwork {
  XCTestExpectation *expectation = [self expectationWithDescription:@"enableNetwork"];
  [self.db enableNetworkWithCompletion:[self completionForExpectation:expectation]];
  [self awaitExpectation:expectation];
}

/**
 * Checks that running the query while online (against the backend/emulator) results in the same
 * documents as running the query while offline. If `expectedDocs` is provided, it also checks
 * that both online and offline query result is equal to the expected documents.
 *
 * This function first performs a "get" for the entire COLLECTION from the server.
 * It then performs the QUERY from CACHE which, results in `executeFullCollectionScan()`
 * It then performs the QUERY from SERVER.
 * It then performs the QUERY from CACHE again, which results in `performQueryUsingRemoteKeys()`.
 * It then ensure that all the above QUERY results are the same.
 *
 * @param collection The collection on which the query is performed.
 * @param query The query to check
 * @param expectedDocs Ordered list of document keys that are expected to match the query
 */
- (void)checkOnlineAndOfflineCollection:(FIRQuery *)collection
                                  query:(FIRQuery *)query
                          matchesResult:(NSArray *)expectedDocs {
  // Note: Order matters. The following has to be done in the specific order:

  // 1- Pre-populate the cache with the entire collection.
  [self readDocumentSetForRef:collection source:FIRFirestoreSourceServer];

  // 2- This performs the query against the cache using full collection scan.
  FIRQuerySnapshot *docsFromCacheFullCollectionScan =
      [self readDocumentSetForRef:query source:FIRFirestoreSourceCache];

  // 3- This goes to the server (backend/emulator).
  FIRQuerySnapshot *docsFromServer = [self readDocumentSetForRef:query
                                                          source:FIRFirestoreSourceServer];

  // 4- This performs the query against the cache using remote keys.
  FIRQuerySnapshot *docsFromCacheUsingRemoteKeys =
      [self readDocumentSetForRef:query source:FIRFirestoreSourceCache];

  XCTAssertEqualObjects(FIRQuerySnapshotGetIDs(docsFromServer),
                        FIRQuerySnapshotGetIDs(docsFromCacheFullCollectionScan));
  XCTAssertEqualObjects(FIRQuerySnapshotGetIDs(docsFromServer),
                        FIRQuerySnapshotGetIDs(docsFromCacheUsingRemoteKeys));
  XCTAssertEqualObjects(FIRQuerySnapshotGetIDs(docsFromServer), expectedDocs);
}

- (const std::shared_ptr<AsyncQueue> &)queueForFirestore:(FIRFirestore *)firestore {
  return [firestore workerQueue];
}

- (void)waitUntil:(BOOL (^)())predicate {
  NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
  double waitSeconds = [self defaultExpectationWaitSeconds];
  while (!predicate() && ([NSDate timeIntervalSinceReferenceDate] - start < waitSeconds)) {
    // This waits for the next event or until the 100ms timeout is reached
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                             beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
  }
  if (!predicate()) {
    XCTFail(@"Timeout");
  }
}

extern "C" NSArray<NSDictionary<NSString *, id> *> *FIRQuerySnapshotGetData(
    FIRQuerySnapshot *docs) {
  NSMutableArray<NSDictionary<NSString *, id> *> *result = [NSMutableArray array];
  for (FIRDocumentSnapshot *doc in docs.documents) {
    [result addObject:doc.data];
  }
  return result;
}

extern "C" NSArray<NSString *> *FIRQuerySnapshotGetIDs(FIRQuerySnapshot *docs) {
  NSMutableArray<NSString *> *result = [NSMutableArray array];
  for (FIRDocumentSnapshot *doc in docs.documents) {
    [result addObject:doc.documentID];
  }
  return result;
}

extern "C" NSArray<NSArray<id> *> *FIRQuerySnapshotGetDocChangesData(FIRQuerySnapshot *docs) {
  NSMutableArray<NSMutableArray<id> *> *result = [NSMutableArray array];
  for (FIRDocumentChange *docChange in docs.documentChanges) {
    NSMutableArray<id> *docChangeData = [NSMutableArray array];
    [docChangeData addObject:@(docChange.type)];
    [docChangeData addObject:docChange.document.documentID];
    [docChangeData addObject:docChange.document.data];
    [result addObject:docChangeData];
  }
  return result;
}

extern "C" NSArray<FIRDocumentReference *> *FIRDocumentReferenceArrayFromQuerySnapshot(
    FIRQuerySnapshot *docs) {
  NSMutableArray<FIRDocumentReference *> *documentReferenceAccumulator =
      [[NSMutableArray alloc] init];
  for (FIRDocumentSnapshot *documentSnapshot in docs.documents) {
    [documentReferenceAccumulator addObject:documentSnapshot.reference];
  }
  return [documentReferenceAccumulator copy];
}

@end

NS_ASSUME_NONNULL_END
