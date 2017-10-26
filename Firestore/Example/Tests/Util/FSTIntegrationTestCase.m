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

@import Firestore;

#import "FSTIntegrationTestCase.h"

#import <FirebaseCommunity/FIRLogger.h>
#import <GRPCClient/GRPCCall+ChannelArg.h>
#import <GRPCClient/GRPCCall+Tests.h>

#import "API/FIRFirestore+Internal.h"
#import "Auth/FSTEmptyCredentialsProvider.h"
#import "Local/FSTLevelDB.h"
#import "Model/FSTDatabaseID.h"
#import "Util/FSTDispatchQueue.h"
#import "Util/FSTUtil.h"

#import "FSTEventAccumulator.h"
#import "FSTTestDispatchQueue.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRFirestore (Testing)
@property(nonatomic, strong) FSTDispatchQueue *workerDispatchQueue;
@end

@implementation FSTIntegrationTestCase {
  NSMutableArray<FIRFirestore *> *_firestores;
}

- (void)setUp {
  [super setUp];

  [self clearPersistence];

  _firestores = [NSMutableArray array];
  self.db = [self firestore];
  self.eventAccumulator = [FSTEventAccumulator accumulatorForTest:self];
}

- (void)tearDown {
  @try {
    for (FIRFirestore *firestore in _firestores) {
      [self shutdownFirestore:firestore];
    }
  } @finally {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [GRPCCall closeOpenConnections];
#pragma clang diagnostic pop
    _firestores = nil;
    [super tearDown];
  }
}

- (void)clearPersistence {
  NSString *levelDBDir = [FSTLevelDB documentsDirectory];
  NSError *error;
  if (![[NSFileManager defaultManager] removeItemAtPath:levelDBDir error:&error]) {
    // file not found is okay.
    XCTAssertTrue(
        [error.domain isEqualToString:NSCocoaErrorDomain] && error.code == NSFileNoSuchFileError,
        @"Failed to clear LevelDB Persistence: %@", error);
  }
}

- (FIRFirestore *)firestore {
  return [self firestoreWithProjectID:[FSTIntegrationTestCase projectID]];
}

+ (NSString *)projectID {
  NSString *project = [[NSProcessInfo processInfo] environment][@"PROJECT_ID"];
  if (!project) {
    project = @"test-db";
  }
  return project;
}

+ (FIRFirestoreSettings *)settings {
  FIRFirestoreSettings *settings = [[FIRFirestoreSettings alloc] init];
  NSString *host = [[NSProcessInfo processInfo] environment][@"DATASTORE_HOST"];
  settings.sslEnabled = YES;
  if (!host) {
    // If host is nil, there is no GoogleService-Info.plist. Check if a hexa integration test
    // configuration is configured. The first bundle location is used by bazel builds. The
    // second is used for github clones.
    host = @"localhost:8081";
    settings.sslEnabled = YES;
    NSString *certsPath =
        [[NSBundle mainBundle] pathForResource:@"PlugIns/IntegrationTests.xctest/CAcert"
                                        ofType:@"pem"];
    if (certsPath == nil) {
      certsPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"CAcert" ofType:@"pem"];
    }
    unsigned long long fileSize =
        [[[NSFileManager defaultManager] attributesOfItemAtPath:certsPath error:nil] fileSize];

    if (fileSize == 0) {
      NSLog(
          @"The cert is not properly configured. Make sure setup_integration_tests.py "
           "has been run.");
    }
    [GRPCCall useTestCertsPath:certsPath testName:@"test_cert_2" forHost:host];
  }
  settings.host = host;
  settings.persistenceEnabled = YES;
  NSLog(@"Configured integration test for %@ with SSL: %@", settings.host,
        settings.sslEnabled ? @"YES" : @"NO");
  return settings;
}

- (FIRFirestore *)firestoreWithProjectID:(NSString *)projectID {
  NSString *persistenceKey = [NSString stringWithFormat:@"db%lu", (unsigned long)_firestores.count];

  FSTTestDispatchQueue *workerDispatchQueue = [FSTTestDispatchQueue
      queueWith:dispatch_queue_create("com.google.firebase.firestore", DISPATCH_QUEUE_SERIAL)];

  FSTEmptyCredentialsProvider *credentialsProvider = [[FSTEmptyCredentialsProvider alloc] init];

  FIRSetLoggerLevel(FIRLoggerLevelDebug);
  // HACK: FIRFirestore expects a non-nil app, but for tests we cheat.
  FIRApp *app = nil;
  FIRFirestore *firestore = [[FIRFirestore alloc] initWithProjectID:projectID
                                                           database:kDefaultDatabaseID
                                                     persistenceKey:persistenceKey
                                                credentialsProvider:credentialsProvider
                                                workerDispatchQueue:workerDispatchQueue
                                                        firebaseApp:app];

  firestore.settings = [FSTIntegrationTestCase settings];

  [_firestores addObject:firestore];
  return firestore;
}

- (void)waitForIdleFirestore:(FIRFirestore *)firestore {
  XCTestExpectation *expectation = [self expectationWithDescription:@"idle"];
  // Note that we wait on any task that is scheduled with a delay of 60s. Currently, the idle
  // timeout is the only task that uses this delay.
  [((FSTTestDispatchQueue *)firestore.workerDispatchQueue) fulfillOnExecution:expectation];
  [self awaitExpectations];
}

- (void)shutdownFirestore:(FIRFirestore *)firestore {
  XCTestExpectation *shutdownCompletion = [self expectationWithDescription:@"shutdown"];
  [firestore shutdownWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNil(error);
    [shutdownCompletion fulfill];
  }];
  [self awaitExpectations];
}

- (NSString *)documentPath {
  return [@"test-collection/" stringByAppendingString:[FSTUtil autoID]];
}

- (FIRDocumentReference *)documentRef {
  return [self.db documentWithPath:[self documentPath]];
}

- (FIRCollectionReference *)collectionRef {
  NSString *collectionName = [@"test-collection-" stringByAppendingString:[FSTUtil autoID]];
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
  [documents enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary<NSString *, id> *value,
                                                 BOOL *stop) {
    FIRDocumentReference *ref = [collection documentWithPath:key];
    [self writeDocumentRef:ref data:value];
  }];
}

- (void)readerAndWriterOnDocumentRef:(void (^)(NSString *path,
                                               FIRDocumentReference *readerRef,
                                               FIRDocumentReference *writerRef))action {
  FIRFirestore *reader = self.db;  // for clarity
  FIRFirestore *writer = [self firestore];

  NSString *path = [self documentPath];
  FIRDocumentReference *readerRef = [reader documentWithPath:path];
  FIRDocumentReference *writerRef = [writer documentWithPath:path];
  action(path, readerRef, writerRef);
}

- (FIRDocumentSnapshot *)readDocumentForRef:(FIRDocumentReference *)ref {
  __block FIRDocumentSnapshot *result;

  XCTestExpectation *expectation = [self expectationWithDescription:@"getData"];
  [ref getDocumentWithCompletion:^(FIRDocumentSnapshot *doc, NSError *_Nullable error) {
    XCTAssertNil(error);
    result = doc;
    [expectation fulfill];
  }];
  [self awaitExpectations];

  return result;
}

- (FIRQuerySnapshot *)readDocumentSetForRef:(FIRQuery *)query {
  __block FIRQuerySnapshot *result;

  XCTestExpectation *expectation = [self expectationWithDescription:@"getData"];
  [query getDocumentsWithCompletion:^(FIRQuerySnapshot *documentSet, NSError *error) {
    XCTAssertNil(error);
    result = documentSet;
    [expectation fulfill];
  }];
  [self awaitExpectations];

  return result;
}

- (FIRDocumentSnapshot *)readSnapshotForRef:(FIRDocumentReference *)ref
                              requireOnline:(BOOL)requireOnline {
  __block FIRDocumentSnapshot *result;

  XCTestExpectation *expectation = [self expectationWithDescription:@"listener"];
  id<FIRListenerRegistration> listener = [ref
      addSnapshotListenerWithOptions:[[FIRDocumentListenOptions options] includeMetadataChanges:YES]
                            listener:^(FIRDocumentSnapshot *snapshot, NSError *error) {
                              XCTAssertNil(error);
                              if (!requireOnline || !snapshot.metadata.fromCache) {
                                result = snapshot;
                                [expectation fulfill];
                              }
                            }];

  [self awaitExpectations];
  [listener remove];

  return result;
}

- (void)writeDocumentRef:(FIRDocumentReference *)ref data:(NSDictionary<NSString *, id> *)data {
  XCTestExpectation *expectation = [self expectationWithDescription:@"setData"];
  [ref setData:data
      completion:^(NSError *_Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
      }];
  [self awaitExpectations];
}

- (void)updateDocumentRef:(FIRDocumentReference *)ref data:(NSDictionary<id, id> *)data {
  XCTestExpectation *expectation = [self expectationWithDescription:@"updateData"];
  [ref updateData:data
       completion:^(NSError *_Nullable error) {
         XCTAssertNil(error);
         [expectation fulfill];
       }];
  [self awaitExpectations];
}

- (void)deleteDocumentRef:(FIRDocumentReference *)ref {
  XCTestExpectation *expectation = [self expectationWithDescription:@"deleteDocument"];
  [ref deleteDocumentWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self awaitExpectations];
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

NSArray<NSDictionary<NSString *, id> *> *FIRQuerySnapshotGetData(FIRQuerySnapshot *docs) {
  NSMutableArray<NSDictionary<NSString *, id> *> *result = [NSMutableArray array];
  for (FIRDocumentSnapshot *doc in docs.documents) {
    [result addObject:doc.data];
  }
  return result;
}

NSArray<NSString *> *FIRQuerySnapshotGetIDs(FIRQuerySnapshot *docs) {
  NSMutableArray<NSString *> *result = [NSMutableArray array];
  for (FIRDocumentSnapshot *doc in docs.documents) {
    [result addObject:doc.documentID];
  }
  return result;
}

@end

NS_ASSUME_NONNULL_END
