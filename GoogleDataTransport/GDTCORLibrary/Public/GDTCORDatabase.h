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

#import <Foundation/Foundation.h>

#import <GoogleDataTransport/GDTCORSqlite.h>

NS_ASSUME_NONNULL_BEGIN

/** This class creates and operates sqlite3 databases. */
@interface GDTCORDatabase : NSObject

/** The user_version PRAGMA of the db. */
@property(atomic) int userVersion;

/** */
@property(atomic, readonly) int schemaVersion;

/** The path of the db. */
@property(nullable, nonatomic, readonly) NSString *path;

/** Instantiates a new sqlite3 db if there's not already a db instance for the given URL.
 *
 * @note Automatically opens the database, but doesn't call -open.
 * @param dbFileURL The file URL of the db, or nil if this should be an in-memory store.
 * @param sql The SQL statements to create the database schema.
 * @param migrationStatements A map of user_versions and their corresponding SQL statements needed
 *   to move from whatever user_version the db is at to the higher version or nil if no migrations
 *   are needed.
 * @return The instantiated db, or nil if the db could not be created for some reason.
 */
- (nullable instancetype)initWithURL:(nullable NSURL *)dbFileURL
                         creationSQL:(NSString *)sql
                 migrationStatements:
                     (nullable NSDictionary<NSNumber *, NSString *> *)migrationStatements;

/** Runs a non-query SQL statement on the db. Non-queries are statements that have no result set.
 *
 * @param sql The SQL statement to run.
 * @param bindings The object bindings of the statement, or nil if there are none. Note: bindings
 *   lists are 1-based.
 * @param cacheStmt Set to YES if you want the db to cache this statement for later use.
 * @return YES if running the non-query was successful, NO otherwise.
 */
- (BOOL)runNonQuery:(NSString *)sql
           bindings:(nullable NSDictionary<NSNumber *, NSString *> *)bindings
          cacheStmt:(BOOL)cacheStmt;

/** Executes a SQL string potentially containing multiple statements without any caching.
 *
 * @param sql The SQL string to run. The string can be multiple SQL statements.
 * @param callback The callback block to handle the result set, or nil if it's not needed.
 * @return YES if running the SQL was successful, NO otherwise.
 */
- (BOOL)executeSQL:(NSString *)sql
          callback:(nullable GDTCORExecuteSQLRowResultCallbackBlock)callback;

/** Runs a query SQL statement on the db. Queries are statements that have results.
 *
 * @param sql The SQL statement to run.
 * @param bindings The object bindings of the statement, or nil if there are none. Note: bindings
 *   lists are 1-based.
 * @param eachRow A block to be run on each row of the result set.
 * @param cacheStmt Set to YES if you want the db to cache this statement for later use.
 * @return YES if running the non-query was successful, NO otherwise.
 */
- (BOOL)runQuery:(NSString *)sql
        bindings:(nullable NSDictionary<NSNumber *, NSString *> *)bindings
         eachRow:(GDTCORSqliteRowResultBlock)eachRow
       cacheStmt:(BOOL)cacheStmt;

/** Re-opens a closed db. DBs are auto-opened at instantiation.
 *
 * @return YES if opening the db was successful, NO otherwise.
 */
- (BOOL)open;

/** Closes an open db.
 *
 * @return YES if closing the db was successful, NO otherwise.
 */
- (BOOL)close;

@end

NS_ASSUME_NONNULL_END
