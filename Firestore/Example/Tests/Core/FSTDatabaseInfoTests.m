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

#import "Core/FSTDatabaseInfo.h"

#import <XCTest/XCTest.h>

#import "Model/FSTDatabaseID.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTDatabaseInfoTests : XCTestCase
@end

@implementation FSTDatabaseInfoTests

- (void)testConstructor {
  FSTDatabaseID *databaseID = [FSTDatabaseID databaseIDWithProject:@"p" database:@"d"];
  FSTDatabaseInfo *databaseInfo = [FSTDatabaseInfo databaseInfoWithDatabaseID:databaseID
                                                               persistenceKey:@"pk"
                                                                         host:@"h"
                                                                   sslEnabled:YES];
  XCTAssertEqualObjects(databaseInfo.databaseID.projectID, @"p");
  XCTAssertEqualObjects(databaseInfo.databaseID.databaseID, @"d");
  XCTAssertEqualObjects(databaseInfo.persistenceKey, @"pk");
  XCTAssertEqualObjects(databaseInfo.host, @"h");
  XCTAssertEqual(databaseInfo.sslEnabled, YES);
}

- (void)testDefaultDatabase {
  FSTDatabaseID *databaseID =
      [FSTDatabaseID databaseIDWithProject:@"p" database:kDefaultDatabaseID];
  FSTDatabaseInfo *databaseInfo = [FSTDatabaseInfo databaseInfoWithDatabaseID:databaseID
                                                               persistenceKey:@"pk"
                                                                         host:@"h"
                                                                   sslEnabled:YES];
  XCTAssertEqualObjects(databaseInfo.databaseID.projectID, @"p");
  XCTAssertEqualObjects(databaseInfo.databaseID.databaseID, @"(default)");
  XCTAssertEqualObjects(databaseInfo.persistenceKey, @"pk");
  XCTAssertEqualObjects(databaseInfo.host, @"h");
  XCTAssertEqual(databaseInfo.sslEnabled, YES);
}

@end

NS_ASSUME_NONNULL_END
