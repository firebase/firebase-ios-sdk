/*
 * Copyright 2022 Google LLC
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

// TODO(csi): Delete this once setIndexConfigurationFromJSON and setIndexConfigurationFromStream
//  are removed.
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

#import <FirebaseFirestore/FirebaseFirestore.h>

#import <XCTest/XCTest.h>

#import "Firestore/Example/Tests/Util/FSTHelpers.h"
#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"
#import "Firestore/Source/Public/FirebaseFirestore/FIRPersistentCacheIndexManager.h"

@interface FIRIndexingTests : FSTIntegrationTestCase
@end

@implementation FIRIndexingTests

// Clears persistence for each test method to have a clean start.
- (void)setUp {
  [super setUp];
  self.db = [self firestore];
  XCTestExpectation *exp = [self expectationWithDescription:@"clear persistence"];
  [self.db clearPersistenceWithCompletion:^(NSError *) {
    [exp fulfill];
  }];
  [self awaitExpectation:exp];
}

- (void)testCanConfigureIndexes {
  NSString *json = @"{\n"
                    "\t\"indexes\": [{\n"
                    "\t\t\t\"collectionGroup\": \"restaurants\",\n"
                    "\t\t\t\"queryScope\": \"COLLECTION\",\n"
                    "\t\t\t\"fields\": [{\n"
                    "\t\t\t\t\t\"fieldPath\": \"price\",\n"
                    "\t\t\t\t\t\"order\": \"ASCENDING\"\n"
                    "\t\t\t\t},\n"
                    "\t\t\t\t{\n"
                    "\t\t\t\t\t\"fieldPath\": \"avgRating\",\n"
                    "\t\t\t\t\t\"order\": \"DESCENDING\"\n"
                    "\t\t\t\t}\n"
                    "\t\t\t]\n"
                    "\t\t},\n"
                    "\t\t{\n"
                    "\t\t\t\"collectionGroup\": \"restaurants\",\n"
                    "\t\t\t\"queryScope\": \"COLLECTION\",\n"
                    "\t\t\t\"fields\": [{\n"
                    "\t\t\t\t\"fieldPath\": \"price\",\n"
                    "\t\t\t\t\"order\": \"ASCENDING\"\n"
                    "\t\t\t}]\n"
                    "\t\t}\n"
                    "\t],\n"
                    "\t\"fieldOverrides\": []\n"
                    "}";

  [self.db setIndexConfigurationFromJSON:json
                              completion:^(NSError *error) {
                                XCTAssertNil(error);
                              }];
}

- (void)testBadJsonDoesNotCrashClient {
  [self.db setIndexConfigurationFromJSON:@"{,"
                              completion:^(NSError *error) {
                                XCTAssertNotNil(error);
                                XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
                                XCTAssertEqual(error.code, FIRFirestoreErrorCodeInvalidArgument);
                              }];
}

- (void)testBadIndexDoesNotCrashClient {
  NSString *json = @"{\n"
                    "\t\"indexes\": [{\n"
                    "\t\t\"collectionGroup\": \"restaurants\",\n"
                    "\t\t\"queryScope\": \"COLLECTION\",\n"
                    "\t\t\"fields\": [{\n"
                    "\t\t\t\"fieldPath\": \"price\",\n"
                    "\t\t\t\"order\": \"ASCENDING\",\n"
                    "\t\t]}\n"
                    "\t}],\n"
                    "\t\"fieldOverrides\": []\n"
                    "}";

  [self.db setIndexConfigurationFromJSON:json
                              completion:^(NSError *error) {
                                XCTAssertNotNil(error);
                                XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
                                XCTAssertEqual(error.code, FIRFirestoreErrorCodeInvalidArgument);
                              }];
}

/**
 * After Auto Index Creation is enabled, through public API there is no way to see the indexes
 * sitting inside SDK. So this test only checks the API of auto index creation.
 */
- (void)testAutoIndexCreationSetSuccessfully {
  // Use persistent disk cache (explicit)
  FIRFirestoreSettings *settings = [self.db settings];
  [settings setCacheSettings:[[FIRPersistentCacheSettings alloc] init]];
  [self.db setSettings:settings];

  FIRCollectionReference *coll = [self collectionRef];
  NSDictionary *testDocs = @{
    @"a" : @{@"match" : @YES},
    @"b" : @{@"match" : @NO},
    @"c" : @{@"match" : @NO},
  };
  [self writeAllDocuments:testDocs toCollection:coll];

  FIRQuery *query = [coll queryWhereField:@"match" isEqualTo:@YES];

  [query getDocumentsWithSource:FIRFirestoreSourceCache
                     completion:^(FIRQuerySnapshot *results, NSError *error) {
                       XCTAssertNil(error);
                       XCTAssertEqual(results.count, 1);
                     }];

  XCTAssertNoThrow([self.db.persistentCacheIndexManager enableIndexAutoCreation]);
  [query getDocumentsWithSource:FIRFirestoreSourceCache
                     completion:^(FIRQuerySnapshot *results, NSError *error) {
                       XCTAssertNil(error);
                       XCTAssertEqual(results.count, 1);
                     }];

  XCTAssertNoThrow([self.db.persistentCacheIndexManager disableIndexAutoCreation]);
  [query getDocumentsWithSource:FIRFirestoreSourceCache
                     completion:^(FIRQuerySnapshot *results, NSError *error) {
                       XCTAssertNil(error);
                       XCTAssertEqual(results.count, 1);
                     }];

  XCTAssertNoThrow([self.db.persistentCacheIndexManager deleteAllIndexes]);
  [query getDocumentsWithSource:FIRFirestoreSourceCache
                     completion:^(FIRQuerySnapshot *results, NSError *error) {
                       XCTAssertNil(error);
                       XCTAssertEqual(results.count, 1);
                     }];
}

- (void)testAutoIndexCreationSetSuccessfullyUsingDefault {
  // Use persistent disk cache (default)
  FIRCollectionReference *coll = [self collectionRef];
  NSDictionary *testDocs = @{
    @"a" : @{@"match" : @YES},
    @"b" : @{@"match" : @NO},
    @"c" : @{@"match" : @NO},
  };
  [self writeAllDocuments:testDocs toCollection:coll];

  FIRQuery *query = [coll queryWhereField:@"match" isEqualTo:@YES];

  [query getDocumentsWithSource:FIRFirestoreSourceCache
                     completion:^(FIRQuerySnapshot *results, NSError *error) {
                       XCTAssertNil(error);
                       XCTAssertEqual(results.count, 1);
                     }];

  XCTAssertNoThrow([self.db.persistentCacheIndexManager enableIndexAutoCreation]);
  [query getDocumentsWithSource:FIRFirestoreSourceCache
                     completion:^(FIRQuerySnapshot *results, NSError *error) {
                       XCTAssertNil(error);
                       XCTAssertEqual(results.count, 1);
                     }];

  XCTAssertNoThrow([self.db.persistentCacheIndexManager disableIndexAutoCreation]);
  [query getDocumentsWithSource:FIRFirestoreSourceCache
                     completion:^(FIRQuerySnapshot *results, NSError *error) {
                       XCTAssertNil(error);
                       XCTAssertEqual(results.count, 1);
                     }];

  XCTAssertNoThrow([self.db.persistentCacheIndexManager deleteAllIndexes]);
  [query getDocumentsWithSource:FIRFirestoreSourceCache
                     completion:^(FIRQuerySnapshot *results, NSError *error) {
                       XCTAssertNil(error);
                       XCTAssertEqual(results.count, 1);
                     }];
}

- (void)testAutoIndexCreationAfterFailsTermination {
  [self terminateFirestore:self.db];

  XCTAssertThrows([self.db.persistentCacheIndexManager enableIndexAutoCreation],
                  @"The client has already been terminated.");

  XCTAssertThrows([self.db.persistentCacheIndexManager disableIndexAutoCreation],
                  @"The client has already been terminated.");

  XCTAssertThrows([self.db.persistentCacheIndexManager deleteAllIndexes],
                  @"The client has already been terminated.");
}

// TODO(b/296100693) Add testing hooks to verify indexes are created as expected.

@end
