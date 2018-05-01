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

#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"

#import <FirebaseCore/FIRLogger.h>
#import <FirebaseFirestore/FIRCollectionReference.h>
#import <FirebaseFirestore/FIRDocumentChange.h>
#import <FirebaseFirestore/FIRDocumentReference.h>
#import <FirebaseFirestore/FIRDocumentSnapshot.h>
#import <FirebaseFirestore/FIRFirestoreSettings.h>
#import <FirebaseFirestore/FIRQuerySnapshot.h>
#import <FirebaseFirestore/FIRSnapshotMetadata.h>
#import <GRPCClient/GRPCCall+ChannelArg.h>
#import <GRPCClient/GRPCCall+Tests.h>

#include <memory>
#include <string>
#include <utility>

#include "Firestore/core/src/firebase/firestore/auth/empty_credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/util/autoid.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "absl/memory/memory.h"

#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/Core/FSTFirestoreClient.h"
#import "Firestore/Source/Local/FSTLevelDB.h"
#import "Firestore/Source/Util/FSTDispatchQueue.h"

#import "Firestore/Example/Tests/Util/FSTEventAccumulator.h"

namespace util = firebase::firestore::util;
using firebase::firestore::auth::CredentialsProvider;
using firebase::firestore::auth::EmptyCredentialsProvider;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::util::CreateAutoId;

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
  settings.timestampsInSnapshotsEnabled = YES;
  NSLog(@"Configured integration test for %@ with SSL: %@", settings.host,
        settings.sslEnabled ? @"YES" : @"NO");
  return settings;
}

- (FIRFirestore *)firestoreWithProjectID:(NSString *)projectID {
  NSString *persistenceKey = [NSString stringWithFormat:@"db%lu", (unsigned long)_firestores.count];

  FSTDispatchQueue *workerDispatchQueue = [FSTDispatchQueue
      queueWith:dispatch_queue_create("com.google.firebase.firestore", DISPATCH_QUEUE_SERIAL)];

  FIRSetLoggerLevel(FIRLoggerLevelDebug);
  // HACK: FIRFirestore expects a non-nil app, but for tests we cheat.
  FIRApp *app = nil;
  std::unique_ptr<CredentialsProvider> credentials_provider =
      absl::make_unique<firebase::firestore::auth::EmptyCredentialsProvider>();

  FIRFirestore *firestore = [[FIRFirestore alloc] initWithProjectID:util::MakeStringView(projectID)
                                                           database:DatabaseId::kDefault
                                                     persistenceKey:persistenceKey
                                                credentialsProvider:std::move(credentials_provider)
                                                workerDispatchQueue:workerDispatchQueue
                                                        firebaseApp:app];

  firestore.settings = [FSTIntegrationTestCase settings];

  [_firestores addObject:firestore];
  return firestore;
}

- (void)shutdownFirestore:(FIRFirestore *)firestore {
  [firestore shutdownWithCompletion:[self completionForExpectationWithName:@"shutdown"]];
  [self awaitExpectations];
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
  [self awaitExpectations];

  return result;
}

- (FIRQuerySnapshot *)readDocumentSetForRef:(FIRQuery *)query {
  return [self readDocumentSetForRef:query source:FIRFirestoreSourceDefault];
}

- (FIRQuerySnapshot *)readDocumentSetForRef:(FIRQuery *)query source:(FIRFirestoreSource)source {
  __block FIRQuerySnapshot *result;

  XCTestExpectation *expectation = [self expectationWithDescription:@"getData"];
  [query getDocumentsWithSource:source
                     completion:^(FIRQuerySnapshot *documentSet, NSError *error) {
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
      addSnapshotListenerWithIncludeMetadataChanges:YES
                                           listener:^(FIRDocumentSnapshot *snapshot,
                                                      NSError *error) {
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
  [ref setData:data completion:[self completionForExpectationWithName:@"setData"]];
  [self awaitExpectations];
}

- (void)updateDocumentRef:(FIRDocumentReference *)ref data:(NSDictionary<id, id> *)data {
  [ref updateData:data completion:[self completionForExpectationWithName:@"updateData"]];
  [self awaitExpectations];
}

- (void)deleteDocumentRef:(FIRDocumentReference *)ref {
  [ref deleteDocumentWithCompletion:[self completionForExpectationWithName:@"deleteDocument"]];
  [self awaitExpectations];
}

- (void)mergeDocumentRef:(FIRDocumentReference *)ref data:(NSDictionary<NSString *, id> *)data {
  [ref setData:data
           merge:YES
      completion:[self completionForExpectationWithName:@"setDataWithMerge"]];
  [self awaitExpectations];
}

- (void)disableNetwork {
  [self.db.client
      disableNetworkWithCompletion:[self completionForExpectationWithName:@"Disable Network."]];
  [self awaitExpectations];
}

- (void)enableNetwork {
  [self.db.client
      enableNetworkWithCompletion:[self completionForExpectationWithName:@"Enable Network."]];
  [self awaitExpectations];
}

- (FSTDispatchQueue *)queueForFirestore:(FIRFirestore *)firestore {
  return firestore.workerDispatchQueue;
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

@end

NS_ASSUME_NONNULL_END
