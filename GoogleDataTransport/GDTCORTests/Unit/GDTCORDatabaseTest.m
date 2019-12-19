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

/** An in-memory db created for each unit test. */
@property(nonatomic) GDTCORDatabase *db;

@end

@implementation GDTCORDatabaseTest

- (void)setUp {
  [super setUp];
  NSString *schema = @"CREATE TABLE \"GDTCORDatabaseTest\" (\"some_text\" TEXT);";
  NSDictionary *migrations = @{@1 : @"PRAGMA user_version = 1;"};
  _db = [[GDTCORDatabase alloc] initWithURL:nil creationSQL:schema migrationStatements:migrations];
  XCTAssertNotNil(_db);
  XCTAssertEqual(_db.userVersion, 1);
  XCTAssertEqual(_db.schemaVersion, 1);
}

- (void)tearDown {
  [super tearDown];
  [_db close];
  _db = nil;
}

/** Tests instantiating a database. */
- (void)testInstantiation {
  NSString *dbPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"test.sqlite3"];
  NSURL *dbFileURL = [NSURL fileURLWithPath:dbPath];
  // Creating another instance should return nil, since there's already one for that file.
  NSString *schema = @"CREATE TABLE \"GDTCORDatabaseTest\" (\"some_text\" TEXT);";
  GDTCORDatabase *db = [[GDTCORDatabase alloc] initWithURL:dbFileURL
                                               creationSQL:schema
                                       migrationStatements:nil];
  XCTAssertNotNil(db);
  GDTCORDatabase *nilDB = [[GDTCORDatabase alloc] initWithURL:dbFileURL
                                                  creationSQL:schema
                                          migrationStatements:nil];
  XCTAssertNil(nilDB);

  // Copy the other db to a new file and open it. No migration should be run.
  NSURL *dbFileURL2 =
      [[dbFileURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"test2.sqlite3"];
  NSError *error;
  [[NSFileManager defaultManager] copyItemAtURL:[NSURL fileURLWithPath:db.path]
                                          toURL:dbFileURL2
                                          error:&error];
  XCTAssertNil(error);
  NSString *schema2 = @"CREATE TABLE \"dontmakeme\" (\"test\" TEXT);";
  GDTCORDatabase *db2 = [[GDTCORDatabase alloc] initWithURL:dbFileURL2
                                                creationSQL:schema2
                                        migrationStatements:nil];
  XCTAssertNotNil(db2);

  XCTAssertTrue([db close]);
  XCTAssertTrue([db2 close]);

  XCTAssertNil(error);
  [[NSFileManager defaultManager] removeItemAtURL:dbFileURL2 error:&error];
  XCTAssertNil(error);
  [[NSFileManager defaultManager] removeItemAtURL:dbFileURL error:&error];
  XCTAssertNil(error);
}

/** Tests setting and getting the user_version pragma. */
- (void)testGetAndSetUserVersion {
  XCTAssertEqual(_db.userVersion, 1);
  _db.userVersion = 1337;
  XCTAssertEqual(_db.userVersion, 1337);
}

/** Tests opening and closing a db. */
- (void)testOpenAndClose {
  XCTAssertTrue([_db close]);
  XCTAssertTrue([_db open]);
}

/** Tests running some statements fails when they're bad and succeeds when they're good. */
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

/** Tests running valid queries is successful. */
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

/** Tests executing a string of SQL. */
- (void)testExecuteSQL {
  NSString *sql = @"CREATE TABLE \"a_new_table\" (\"some_int\" INTEGER); ALTER TABLE a_new_table "
                  @"ADD test_text BLOB;";
  XCTAssertTrue([_db executeSQL:sql callback:nil]);
  NSString *nonQuery = @"INSERT INTO a_new_table(some_int, test_text) VALUES (?, ?);";
  NSDictionary *bindings = @{@(1) : @"1234567", @(2) : @"testing 123"};
  XCTAssertTrue([_db runNonQuery:nonQuery bindings:bindings cacheStmt:YES]);
  XCTestExpectation *resultExpectation = [self expectationWithDescription:@"result block called"];
  XCTAssertTrue([_db runQuery:@"SELECT some_int, test_text FROM a_new_table;"
                     bindings:nil
                      eachRow:^(sqlite3_stmt *_Nonnull stmt) {
                        int result = sqlite3_column_int(stmt, 0);
                        XCTAssertEqual(result, 1234567);
                        const char *textResult = (const char *)sqlite3_column_text(stmt, 1);
                        XCTAssertTrue(textResult != NULL);
                        XCTAssertEqualObjects([NSString stringWithUTF8String:textResult],
                                              @"testing 123");
                        [resultExpectation fulfill];
                      }
                    cacheStmt:YES]);
  [self waitForExpectations:@[ resultExpectation ] timeout:0.0];
}

@end
