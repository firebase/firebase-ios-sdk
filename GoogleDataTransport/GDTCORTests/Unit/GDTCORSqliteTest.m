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

#import <GoogleDataTransport/GDTCORSqlite.h>

@interface GDTCORSqliteTest : GDTCORTestCase

/** */
@property(nonatomic) NSString *currentDBPath;

/** */
@property(nonatomic) sqlite3 *db;

@end

@implementation GDTCORSqliteTest

// Creates and opens a db.
- (void)setUp {
  [super setUp];
  self.currentDBPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"test.sqlite3"];
  XCTAssertTrue(GDTCORSQLOpenDB(&_db, self.currentDBPath), @"There was a failure opening the db");
  XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:self.currentDBPath],
                @"The db wasn't created at the path");
}

// Closes the db, deletes the file.
- (void)tearDown {
  [super tearDown];
  XCTAssertTrue(GDTCORSQLCloseDB(_db), @"The db wasn't closed successfully");
  NSError *error;
  [[NSFileManager defaultManager] removeItemAtPath:self.currentDBPath error:&error];
  XCTAssertNil(error);
}

- (void)testInMemoryDB {
  sqlite3 *db;
  XCTAssertTrue(GDTCORSQLOpenDB(&db, @":memory:"));
  sqlite3_stmt *setStmt, *getStmt;
  XCTAssertTrue(GDTCORSQLCompileSQL(&setStmt, db, @"PRAGMA user_version = 123;"));
  XCTAssertTrue(GDTCORSQLCompileSQL(&getStmt, db, @"PRAGMA user_version;"));
  XCTAssertTrue(GDTCORSQLRunNonQuery(db, setStmt));
  XCTestExpectation *expectation = [self expectationWithDescription:@"row block ran"];
  XCTAssertTrue(GDTCORSQLRunQuery(db, getStmt, ^(sqlite3_stmt *stmt) {
    int userVersion = sqlite3_column_int(getStmt, 0);
    XCTAssertEqual(userVersion, 123);
    [expectation fulfill];
  }));
  [self waitForExpectations:@[ expectation ] timeout:0];
  XCTAssertTrue(GDTCORSQLFinalize(setStmt));
  XCTAssertTrue(GDTCORSQLFinalize(getStmt));
  XCTAssertTrue(GDTCORSQLCloseDB(db));
}

/** Tests calling functions with bad arguments. */
- (void)testBadInputToSQLFunctions {
  sqlite3 *localDB;
  XCTAssertFalse(GDTCORSQLOpenDB(&localDB, @""));
  sqlite3_stmt *stmt;
  localDB = (sqlite3 *)"garbage";
  // Has a bad table.
  XCTAssertFalse(GDTCORSQLCompileSQL(&stmt, localDB, @"PRAGMA user_version = 456;"));
  // Has bad SQL.
  XCTAssertFalse(GDTCORSQLCompileSQL(&stmt, _db, @"NOT a real SQL statement;"));
  XCTAssertFalse(GDTCORSQLCompileSQL(&stmt, _db, @""));
}

/** Tests setting and gett the user_version pragma. */
- (void)testSettingUserVersionPragma {
  sqlite3_stmt *setStmt, *getStmt;
  XCTAssertTrue(GDTCORSQLCompileSQL(&setStmt, _db, @"PRAGMA user_version = 123;"));
  XCTAssertTrue(GDTCORSQLCompileSQL(&getStmt, _db, @"PRAGMA user_version;"));
  XCTAssertTrue(GDTCORSQLRunNonQuery(_db, setStmt));
  XCTestExpectation *expectation = [self expectationWithDescription:@"row block ran"];
  XCTAssertTrue(GDTCORSQLRunQuery(_db, getStmt, ^(sqlite3_stmt *stmt) {
    int userVersion = sqlite3_column_int(getStmt, 0);
    XCTAssertEqual(userVersion, 123);
    [expectation fulfill];
  }));
  [self waitForExpectations:@[ expectation ] timeout:0];
  XCTAssertTrue(GDTCORSQLFinalize(setStmt));
  XCTAssertTrue(GDTCORSQLFinalize(getStmt));
}

/** Tests creating a table in the open db. */
- (void)testCreationOfTable {
  NSString *tableCreationString = @"CREATE TABLE \"\" (\"field_two\" TEXT, \"field_one\" INTEGER);";
  sqlite3_stmt *tableCreation;
  XCTAssertTrue(GDTCORSQLCompileSQL(&tableCreation, _db, tableCreationString));
  XCTAssertTrue(GDTCORSQLRunNonQuery(_db, tableCreation));
  XCTAssertTrue(GDTCORSQLFinalize(tableCreation));
}

/** Tests inserting something into a table. */
- (void)testInsertionIntoTable {
  NSString *tableCreationString = @"CREATE TABLE \"test_table\" ("
                                   "  \"field_one\" INTEGER,"
                                   "  \"field_two\" TEXT"
                                   ");";
  NSString *insertString = @"INSERT INTO test_table(field_one, field_two) VALUES (1, \"hello\")";
  sqlite3_stmt *tableCreation, *insert;
  XCTAssertTrue(GDTCORSQLCompileSQL(&tableCreation, _db, tableCreationString));
  XCTAssertTrue(GDTCORSQLRunNonQuery(_db, tableCreation));
  XCTAssertTrue(GDTCORSQLFinalize(tableCreation));
  XCTAssertTrue(GDTCORSQLCompileSQL(&insert, _db, insertString));
  XCTAssertTrue(GDTCORSQLRunNonQuery(_db, insert));
  XCTAssertTrue(GDTCORSQLFinalize(insert));
}

/** Tests running a non-query with a bound param. */
- (void)testNonQueryBinding {
  NSString *tableCreationString = @"CREATE TABLE \"test_table\" ("
                                   "  \"field_one\" INTEGER,"
                                   "  \"field_two\" TEXT"
                                   ");";
  NSString *insertString = @"INSERT INTO test_table(field_one, field_two) VALUES (?, ?);";
  sqlite3_stmt *tableCreation;
  XCTAssertTrue(GDTCORSQLCompileSQL(&tableCreation, _db, tableCreationString));
  XCTAssertTrue(GDTCORSQLRunNonQuery(_db, tableCreation));
  XCTAssertTrue(GDTCORSQLFinalize(tableCreation));

  sqlite3_stmt *insert;
  XCTAssertTrue(GDTCORSQLCompileSQL(&insert, _db, insertString));
  XCTAssertTrue(GDTCORSQLBindObjectToParam(insert, 1, @(1234)));
  XCTAssertTrue(GDTCORSQLBindObjectToParam(insert, 2, @"hello, world"));
  XCTAssertTrue(GDTCORSQLRunNonQuery(_db, insert));
  XCTAssertTrue(GDTCORSQLFinalize(insert));
}

/** Tests the reseting of a statement. */
- (void)testStatementReset {
  NSString *tableCreationString = @"CREATE TABLE \"test_table\" ("
                                   "  \"field_one\" INTEGER,"
                                   "  \"field_two\" TEXT"
                                   ");";
  NSString *insertString = @"INSERT INTO test_table(field_one, field_two) VALUES (?, ?);";

  sqlite3_stmt *tableCreation;
  XCTAssertTrue(GDTCORSQLCompileSQL(&tableCreation, _db, tableCreationString));
  XCTAssertTrue(GDTCORSQLRunNonQuery(_db, tableCreation));
  XCTAssertTrue(GDTCORSQLFinalize(tableCreation));

  sqlite3_stmt *insert;
  XCTAssertTrue(GDTCORSQLCompileSQL(&insert, _db, insertString));
  XCTAssertTrue(GDTCORSQLBindObjectToParam(insert, 1, @(1234)));
  XCTAssertTrue(GDTCORSQLBindObjectToParam(insert, 2, @"hello, world"));
  XCTAssertTrue(GDTCORSQLRunNonQuery(_db, insert));
  XCTAssertTrue(GDTCORSQLReset(insert));
  XCTAssertTrue(GDTCORSQLBindObjectToParam(insert, 1, @(4567)));
  XCTAssertTrue(GDTCORSQLBindObjectToParam(insert, 2, @"hello, again?"));
  XCTAssertTrue(GDTCORSQLRunNonQuery(_db, insert));
  XCTAssertTrue(GDTCORSQLFinalize(insert));
}

/** Tests running a query with a bound param. */
- (void)testQueryBinding {
  NSString *tableCreationString = @"CREATE TABLE \"test_table\" ("
                                   "  \"field_one\" INTEGER,"
                                   "  \"field_two\" TEXT"
                                   ");";
  NSString *insertString = @"INSERT INTO test_table(field_one, field_two) VALUES (?, ?);";
  NSString *queryString = @"SELECT * FROM test_table WHERE field_one = ?;";

  sqlite3_stmt *tableCreation;
  XCTAssertTrue(GDTCORSQLCompileSQL(&tableCreation, _db, tableCreationString));
  XCTAssertTrue(GDTCORSQLRunNonQuery(_db, tableCreation));
  XCTAssertTrue(GDTCORSQLFinalize(tableCreation));

  sqlite3_stmt *insert;
  XCTAssertTrue(GDTCORSQLCompileSQL(&insert, _db, insertString));
  XCTAssertTrue(GDTCORSQLBindObjectToParam(insert, 1, @(9999)));
  XCTAssertTrue(GDTCORSQLBindObjectToParam(insert, 2, @"hello, world"));
  XCTAssertTrue(GDTCORSQLRunNonQuery(_db, insert));
  XCTAssertTrue(GDTCORSQLReset(insert));
  XCTAssertTrue(GDTCORSQLBindObjectToParam(insert, 1, @(10000)));
  XCTAssertTrue(GDTCORSQLBindObjectToParam(insert, 2, @"hello, again?"));
  XCTAssertTrue(GDTCORSQLRunNonQuery(_db, insert));
  XCTAssertTrue(GDTCORSQLFinalize(insert));

  sqlite3_stmt *query;
  XCTAssertTrue(GDTCORSQLCompileSQL(&query, _db, queryString));
  XCTAssertTrue(GDTCORSQLBindObjectToParam(query, 1, @(9999)));
  XCTestExpectation *expectation = [self expectationWithDescription:@"query was run"];
  // There should only be a single result, and therefore, a single fulfill.
  expectation.assertForOverFulfill = YES;
  XCTAssertTrue(GDTCORSQLRunQuery(_db, query, ^(sqlite3_stmt *stmt) {
    int fieldOne = sqlite3_column_int(query, 0);
    XCTAssertEqual(fieldOne, 9999);
    const unsigned char *fieldTwo = sqlite3_column_text(query, 1);
    XCTAssertEqualObjects([[NSString alloc] initWithUTF8String:(char *)fieldTwo], @"hello, world");
    [expectation fulfill];
  }));
  XCTAssertTrue(GDTCORSQLReset(query));
  XCTAssertTrue(GDTCORSQLBindObjectToParam(query, 1, @(1)));
  XCTAssertTrue(GDTCORSQLRunQuery(_db, query, ^(sqlite3_stmt *stmt) {
    XCTFail(@"The block should never be run for empty result sets.");
  }));
  [self waitForExpectations:@[ expectation ] timeout:0];
  XCTAssertTrue(GDTCORSQLFinalize(query));
}

@end
