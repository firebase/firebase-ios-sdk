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

#import <FirebaseFirestore/FirebaseFirestore.h>

#import <XCTest/XCTest.h>

#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"

@interface FIRIndexingTests : FSTIntegrationTestCase
@end

@implementation FIRIndexingTests

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

- (void)testCanConfigureIndexes {
  NSString* json = @"{\n"
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
                              completion:^(NSError* error) {
                                XCTAssertNil(error);
                              }];
}

- (void)testBadJsonDoesNotCrashClient {
  [self.db setIndexConfigurationFromJSON:@"{,"
                              completion:^(NSError* error) {
                                XCTAssertNotNil(error);
                                XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
                                XCTAssertEqual(error.code, FIRFirestoreErrorCodeInvalidArgument);
                              }];
}

- (void)testBadIndexDoesNotCrashClient {
  NSString* json = @"{\n"
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
                              completion:^(NSError* error) {
                                XCTAssertNotNil(error);
                                XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
                                XCTAssertEqual(error.code, FIRFirestoreErrorCodeInvalidArgument);
                              }];
}

@end
