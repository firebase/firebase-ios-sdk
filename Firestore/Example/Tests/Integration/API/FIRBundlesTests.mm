/*
 * Copyright 2021 Google LLC
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
#import <FirebaseFirestore/FirebaseFirestore.h>

#import <XCTest/XCTest.h>

#import "Firestore/Source/API/FIRLoadBundleTask+Internal.h"

#import "Firestore/Example/Tests/Util/FSTEventAccumulator.h"
#import "Firestore/Example/Tests/Util/FSTHelpers.h"
#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"

#include "Firestore/core/src/util/string_apple.h"
#include "Firestore/core/test/unit/testutil/bundle_builder.h"

using firebase::firestore::testutil::CreateBundle;
using firebase::firestore::util::MakeNSString;
using firebase::firestore::util::MakeString;

@interface FIRBundlesTests : FSTIntegrationTestCase
@end

@implementation FIRBundlesTests

// Clears persistence for each test method to have a clean start.
- (void)setUp {
  [super setUp];
  self.db = [self firestore];
  XCTestExpectation* exp = [self expectationWithDescription:@"clear persistence"];
  [self.db clearPersistenceWithCompletion:^(NSError*) {
    [exp fulfill];
  }];
  [self awaitExpectation:exp];
}

- (void)verifyProgress:(FIRLoadBundleTaskProgress*)progress hasLoadedDocument:(int32_t)loaded {
  XCTAssertEqual(progress.state, FIRLoadBundleTaskStateInProgress);
  XCTAssertLessThanOrEqual(progress.bytesLoaded, progress.totalBytes);
  XCTAssertLessThanOrEqual(progress.documentsLoaded, progress.totalDocuments);
  XCTAssertEqual(progress.documentsLoaded, loaded);
}

- (void)verifySuccessProgress:(FIRLoadBundleTaskProgress*)progress {
  XCTAssertEqual(progress.state, FIRLoadBundleTaskStateSuccess);
  XCTAssertGreaterThan(progress.bytesLoaded, 0);
  XCTAssertEqual(progress.bytesLoaded, progress.totalBytes);
  XCTAssertGreaterThan(progress.documentsLoaded, 0);
  XCTAssertEqual(progress.documentsLoaded, progress.totalDocuments);
}

- (void)verifyErrorProgress:(FIRLoadBundleTaskProgress*)progress {
  XCTAssertEqual(progress.state, FIRLoadBundleTaskStateError);
  XCTAssertEqual(progress.bytesLoaded, 0);
  XCTAssertEqual(progress.documentsLoaded, 0);
}

- (std::string)defaultBundle {
  return CreateBundle(MakeString([FSTIntegrationTestCase projectID]));
}

- (std::string)bundleForProject:(NSString*)projectID {
  return CreateBundle(MakeString(projectID));
}

- (void)verifyQueryResults {
  FIRCollectionReference* query = [self.db collectionWithPath:@"coll-1"];
  FIRQuerySnapshot* snapshot = [self readDocumentSetForRef:query source:FIRFirestoreSourceCache];
  NSArray* expected = @[ @{@"bar" : @1L, @"k" : @"a"}, @{@"bar" : @2L, @"k" : @"b"} ];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), expected);

  [self verifyNamedQuery:@"limit" hasResult:@[ @{@"bar" : @2L, @"k" : @"b"} ]];
  [self verifyNamedQuery:@"limit-to-last" hasResult:@[ @{@"bar" : @1L, @"k" : @"a"} ]];
}

- (void)verifyNamedQuery:(NSString*)name hasResult:(NSArray*)expected {
  XCTestExpectation* expectation = [self expectationWithDescription:@"namedQuery"];
  __block FIRQuery* query;
  [self.db getQueryNamed:name
              completion:^(FIRQuery* q) {
                query = q;
                [expectation fulfill];
              }];
  [self awaitExpectation:expectation];
  FIRQuerySnapshot* snapshot = [self readDocumentSetForRef:query source:FIRFirestoreSourceCache];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), expected);
}

- (void)testLoadWithDocumentsThatAreAlreadyPulledFromBackend {
  [self writeDocumentRef:[self.db documentWithPath:@"coll-1/a"] data:@{@"bar" : @"newValueA"}];
  [self writeDocumentRef:[self.db documentWithPath:@"coll-1/b"] data:@{@"bar" : @"newValueB"}];

  // Finishing receiving backend event.
  FIRCollectionReference* collection = [self.db collectionWithPath:@"coll-1"];
  id<FIRListenerRegistration> registration =
      [collection addSnapshotListener:self.eventAccumulator.valueEventHandler];
  [self.eventAccumulator awaitRemoteEvent];

  // We should see no more snapshots from loading the bundle, because the data there is older.
  [self.eventAccumulator assertNoAdditionalEvents];

  auto bundle = [self defaultBundle];
  NSMutableArray* progresses = [[NSMutableArray alloc] init];
  __block FIRLoadBundleTaskProgress* result;
  XCTestExpectation* expectation = [self expectationWithDescription:@"loading complete"];
  FIRLoadBundleTask* task =
      [self.db loadBundle:[MakeNSString(bundle) dataUsingEncoding:NSUTF8StringEncoding]
               completion:^(FIRLoadBundleTaskProgress* progress, NSError* error) {
                 result = progress;
                 XCTAssertNil(error);
                 [expectation fulfill];
               }];
  [task addObserver:^(FIRLoadBundleTaskProgress* progress) {
    [progresses addObject:progress];
  }];

  [self awaitExpectation:expectation];

  XCTAssertEqual(4ul, progresses.count);
  [self verifyProgress:progresses[0] hasLoadedDocument:0];
  [self verifyProgress:progresses[1] hasLoadedDocument:1];
  [self verifyProgress:progresses[2] hasLoadedDocument:2];
  [self verifySuccessProgress:progresses[3]];
  XCTAssertEqualObjects(progresses[3], result);

  [self verifyNamedQuery:@"limit" hasResult:@[ @{@"bar" : @"newValueB"} ]];
  [self verifyNamedQuery:@"limit-to-last" hasResult:@[ @{@"bar" : @"newValueA"} ]];

  [registration remove];
}

- (void)testLoadDocumentsWithProgressUpdates {
  NSMutableArray* progresses = [[NSMutableArray alloc] init];
  auto bundle = [self defaultBundle];

  __block FIRLoadBundleTaskProgress* result;
  XCTestExpectation* expectation = [self expectationWithDescription:@"loading complete"];
  FIRLoadBundleTask* task =
      [self.db loadBundle:[MakeNSString(bundle) dataUsingEncoding:NSUTF8StringEncoding]
               completion:^(FIRLoadBundleTaskProgress* progress, NSError* error) {
                 result = progress;
                 XCTAssertNil(error);
                 [expectation fulfill];
               }];
  [task addObserver:^(FIRLoadBundleTaskProgress* progress) {
    [progresses addObject:progress];
  }];

  [self awaitExpectation:expectation];

  XCTAssertEqual(4ul, progresses.count);
  [self verifyProgress:progresses[0] hasLoadedDocument:0];
  [self verifyProgress:progresses[1] hasLoadedDocument:1];
  [self verifyProgress:progresses[2] hasLoadedDocument:2];
  [self verifySuccessProgress:progresses[3]];
  XCTAssertEqualObjects(progresses[3], result);

  [self verifyQueryResults];
}

- (void)testLoadForASecondTimeSkips {
  auto bundle = [self defaultBundle];
  [self.db loadBundle:[MakeNSString(bundle) dataUsingEncoding:NSUTF8StringEncoding]];

  // Load for a second time
  NSMutableArray* progresses = [[NSMutableArray alloc] init];
  __block FIRLoadBundleTaskProgress* result;
  XCTestExpectation* expectation = [self expectationWithDescription:@"loading complete"];
  FIRLoadBundleTask* task =
      [self.db loadBundle:[MakeNSString(bundle) dataUsingEncoding:NSUTF8StringEncoding]
               completion:^(FIRLoadBundleTaskProgress* progress, NSError* error) {
                 result = progress;
                 XCTAssertNil(error);
                 [expectation fulfill];
               }];
  [task addObserver:^(FIRLoadBundleTaskProgress* progress) {
    [progresses addObject:progress];
  }];

  [self awaitExpectation:expectation];

  XCTAssertEqual(1ul, progresses.count);
  [self verifySuccessProgress:progresses[0]];
  XCTAssertEqualObjects(progresses[0], result);

  [self verifyQueryResults];
}

- (void)testLoadedDocumentsShouldNotBeGarbageCollectedRightAway {
  auto settings = [self.db settings];
  [settings setPersistenceEnabled:FALSE];
  [self.db setSettings:settings];

  auto bundle = [self defaultBundle];
  __block FIRLoadBundleTaskProgress* result;
  XCTestExpectation* expectation = [self expectationWithDescription:@"loading complete"];
  [self.db loadBundle:[MakeNSString(bundle) dataUsingEncoding:NSUTF8StringEncoding]
           completion:^(FIRLoadBundleTaskProgress* progress, NSError* error) {
             result = progress;
             XCTAssertNil(error);
             [expectation fulfill];
           }];
  [self awaitExpectation:expectation];
  [self verifySuccessProgress:result];

  // Read a different collection. This will trigger GC.
  [self readDocumentSetForRef:[self.db collectionWithPath:@"coll-other"]];

  // Read the loaded documents, expecting them to exist in cache. With memory GC, the documents
  // would get GC-ed if we did not hold the document keys in an "umbrella" target. See
  // LocalStore for details.
  [self verifyQueryResults];
}

- (void)testLoadBundlesFromOtherProjectFails {
  NSMutableArray* progresses = [[NSMutableArray alloc] init];
  __block FIRLoadBundleTaskProgress* result;
  XCTestExpectation* expectation = [self expectationWithDescription:@"loading complete"];
  auto bundle = [self bundleForProject:@"OtherProject"];
  FIRLoadBundleTask* task =
      [self.db loadBundle:[MakeNSString(bundle) dataUsingEncoding:NSUTF8StringEncoding]
               completion:^(FIRLoadBundleTaskProgress* progress, NSError* error) {
                 result = progress;
                 XCTAssertNotNil(error);
                 [expectation fulfill];
               }];
  [task addObserver:^(FIRLoadBundleTaskProgress* progress) {
    [progresses addObject:progress];
  }];
  [self awaitExpectation:expectation];

  XCTAssertEqual(2ul, progresses.count);
  [self verifyProgress:progresses[0] hasLoadedDocument:0];
  [self verifyErrorProgress:progresses[1]];
  XCTAssertEqualObjects(progresses[1], result);
}

@end
