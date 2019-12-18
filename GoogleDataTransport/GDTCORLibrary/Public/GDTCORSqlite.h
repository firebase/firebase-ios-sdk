/*
 * Copyright 2018 Google
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
#import <sqlite3.h>

NS_ASSUME_NONNULL_BEGIN

/** Convenience typedef to define a block ran on each row of a query result. */
typedef void (^GDTCORSqliteRowResultBlock)(sqlite3_stmt *stmt);

/** Convenience typedef for a block invoked in the callback of sqlite3_exec. */
typedef int (^GDTCORExecuteSQLRowResultCallbackBlock)(NSDictionary<NSString *, NSString *> *row);

/** Instantiates a sqlite3 object given the filename.
 *
 * @param db The db reference to instantiate.
 * @param path The path to make a db at. Sqlite special paths like :memory: can be used.
 * @return YES if the db was successfully opened, NO otherwise.
 */
BOOL GDTCORSQLOpenDB(sqlite3 *_Nullable *_Nullable db, NSString *path);

/** Closes the given db.
 *
 * @param db The db reference to close.
 * @return YES if the db was successfully closed, NO otherwise.
 */
BOOL GDTCORSQLCloseDB(sqlite3 *db);

/** Compiles the given statement string in the context of the given db.
 *
 * @param stmt The stmt point to instantiate.
 * @param db The db with regard to which the stmt will be compiled.
 * @param statement The SQL statement to compile.
 * @return YES if the SQL was successfully compiled, NO otherwise.
 */
BOOL GDTCORSQLCompileSQL(sqlite3_stmt *_Nullable *_Nullable stmt, sqlite3 *db, NSString *statement);

/** Resets the given statement.
 *
 * @param stmt The statement to reset.
 * @return YES if the statement was successfully reset, NO otherwise.
 */
BOOL GDTCORSQLReset(sqlite3_stmt *stmt);

/** Finalizes a statement.
 *
 * @note It is an API violation to use this statement with recompiling it.
 *
 * @param stmt The statement to finalize.
 * @return YES if the statement was successfully finalized, NO otherwise.
 */
BOOL GDTCORSQLFinalize(sqlite3_stmt *stmt);

/** Runs a non-query statement.
 *
 * @param db The db to run the stmt on.
 * @param stmt The statement to run.
 * @return YES if the statement was successfully run, NO otherwise.
 */
BOOL GDTCORSQLRunNonQuery(sqlite3 *db, sqlite3_stmt *stmt);

/** Runs a query statement.
 *
 * @param db The db to run the stmt on.
 * @param stmt The statement to run.
 * @param eachRow A block that will be called on each row of the results, if any.
 * @return YES if the statement was successfully run, NO otherwise.
 */
BOOL GDTCORSQLRunQuery(sqlite3 *db, sqlite3_stmt *stmt, GDTCORSqliteRowResultBlock eachRow);

/** Binds an ObjC object to a '?' param at the given column index of the statement.
 *
 * @param stmt The stmt to bind to.
 * @param index The index of the param.
 * @param object The object to be bound.
 * @return YES if the statement was successfully run, NO otherwise.
 */
BOOL GDTCORSQLBindObjectToParam(sqlite3_stmt *stmt, int index, id object);

NS_ASSUME_NONNULL_END
