/*
 * Copyright 2019 Google
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

#import "GDTCORTests/Unit/GDTCORTestCase.h"

#import "GDTCORLibrary/Private/GDTCORDatabase_Private.h"
#import "GDTCORLibrary/Public/GDTCORDatabase.h"

@interface GDTCORDatabaseTest : GDTCORTestCase

/** */
@property(nonatomic) GDTCORDatabase *db;

@end

@implementation GDTCORDatabaseTest

- (void)setUp {
  [super setUp];
  NSDictionary *migrations = @{@1 : @"CREATE TABLE \"GDTCORDatabaseTest\" (\"some_text\" TEXT);"};
  _db = [[GDTCORDatabase alloc] initWithURL:nil migrationStatements:migrations];
  XCTAssertNotNil(_db);
}

- (void)tearDown {
  [super tearDown];
  [_db close];
  _db = nil;
}

/** */
- (void)testInstantiation {
  NSString *dbPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"test.sqlite3"];
  NSURL *dbFileURL = [NSURL fileURLWithPath:dbPath];
  // Creating another instance should return nil, since there's already one for that file.
  NSDictionary *migrations = @{@1 : @"CREATE TABLE \"testing\" (\"some_text\" TEXT);"};
  GDTCORDatabase *db = [[GDTCORDatabase alloc] initWithURL:dbFileURL
                                       migrationStatements:migrations];
  XCTAssertNotNil(db);
  GDTCORDatabase *nilDB = [[GDTCORDatabase alloc] initWithURL:dbFileURL
                                          migrationStatements:migrations];
  XCTAssertNil(nilDB);

  // Copy the other db to a new file and open it. No migration should be run.
  NSURL *dbFileURL2 =
      [[dbFileURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"test2.sqlite3"];
  NSError *error;
  [[NSFileManager defaultManager] copyItemAtURL:[NSURL fileURLWithPath:db.path]
                                          toURL:dbFileURL2
                                          error:&error];
  XCTAssertNil(error);
  NSDictionary *migrations2 = @{@1 : @"CREATE TABLE \"dontmakeme\" (\"test\" TEXT);"};
  GDTCORDatabase *db2 = [[GDTCORDatabase alloc] initWithURL:dbFileURL2
                                        migrationStatements:migrations2];
  XCTAssertNotNil(db2);

  XCTAssertTrue([db close]);
  XCTAssertTrue([db2 close]);

  XCTAssertNil(error);
  [[NSFileManager defaultManager] removeItemAtURL:dbFileURL2 error:&error];
  XCTAssertNil(error);
  [[NSFileManager defaultManager] removeItemAtURL:dbFileURL error:&error];
  XCTAssertNil(error);
}

/** */
- (void)testGetAndSetUserVersion {
  XCTAssertEqual(_db.userVersion, 1);
  _db.userVersion = 1337;
  XCTAssertEqual(_db.userVersion, 1337);
}

/** */
- (void)testOpenAndClose {
  XCTAssertTrue([_db close]);
  XCTAssertTrue([_db open]);
}

/** */
- (void)testRunningSomeStatements {
  XCTAssertFalse([_db runNonQuery:@"" bindings:nil cacheStmt:NO]);
  XCTAssertFalse([_db runNonQuery:@"NOT a STATEMENT" bindings:nil cacheStmt:NO]);
  XCTAssertTrue([_db runNonQuery:@"CREATE TABLE \"abc\" (\"some_text\" TEXT);"
                        bindings:nil
                       cacheStmt:NO]);
  XCTAssertTrue([_db runNonQuery:@"INSERT INTO abc(some_text) VALUES (?);"
                        bindings:@{@1 : @"test"}
                       cacheStmt:YES]);
  XCTAssertTrue(CFDictionaryGetValue(_db.stmtCache, @"INSERT INTO abc(some_text) VALUES (?);") !=
                NULL);
  XCTAssertTrue([_db runNonQuery:@"INSERT INTO abc(some_text) VALUES (?);"
                        bindings:@{@1 : @"test2"}
                       cacheStmt:YES]);
}

/** */
- (void)testRunningSomeQueries {
  XCTAssertTrue([_db runNonQuery:@"CREATE TABLE \"abc\" (\"some_text\" TEXT);"
                        bindings:nil
                       cacheStmt:NO]);
  XCTAssertTrue([_db runNonQuery:@"INSERT INTO abc(some_text) VALUES (?);"
                        bindings:@{@1 : @"test"}
                       cacheStmt:YES]);
  XCTAssertTrue(CFDictionaryGetValue(_db.stmtCache, @"INSERT INTO abc(some_text) VALUES (?);") !=
                NULL);
  XCTAssertTrue([_db runNonQuery:@"INSERT INTO abc(some_text) VALUES (?);"
                        bindings:@{@1 : @"test2"}
                       cacheStmt:YES]);
  XCTAssertTrue([_db runNonQuery:@"INSERT INTO abc(some_text) VALUES (?);"
                        bindings:@{@1 : @"test3"}
                       cacheStmt:YES]);
  XCTAssertTrue([_db runNonQuery:@"INSERT INTO abc(some_text) VALUES (?);"
                        bindings:@{@1 : @"test4"}
                       cacheStmt:YES]);
  XCTestExpectation *resultExpectation = [self expectationWithDescription:@"result block called"];
  resultExpectation.assertForOverFulfill = NO;
  [_db runQuery:@"SELECT * FROM abc"
       bindings:nil
        eachRow:^(sqlite3_stmt *stmt) {
          static int resultCount = 0;
          resultCount++;
          XCTAssertTrue(resultCount > 0);
          XCTAssertTrue(resultCount <= 4, @"number of results was greater than 4: %d", resultCount);
          const char *textResult = (const char *)sqlite3_column_text(stmt, 0);
          XCTAssertTrue(textResult != NULL);
          XCTAssertTrue([[NSString stringWithUTF8String:textResult] hasPrefix:@"test"]);
          [resultExpectation fulfill];
        }
      cacheStmt:NO];
  [self waitForExpectations:@[ resultExpectation ] timeout:0.0];
}

@end
