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

#import "GDTCORLibrary/Public/GDTCORDatabase.h"
#import "GDTCORLibrary/Private/GDTCORDatabase_Private.h"

#import "GDTCORLibrary/Public/GDTCORConsoleLogger.h"

#pragma mark - Helper functions and statics

/** A shared cache of db instances to SQL files */
static NSMutableDictionary<NSString *, GDTCORDatabase *> *instancesToDBFiles;

/** Sets the user_version PRAGMA of the sqlite db.
 *
 * @note -1 is a reserved value to signify an error fetching the user_version value.
 *
 * @param db The db to alter.
 * @param userVersion The user_version value to set.
 */
static void SetUserVersion(sqlite3 *db, int userVersion) {
  if (!db) {
    GDTCORLogError(GDTCORMCEDatabaseError, @"%@", @"The database is closed");
    return;
  }
  sqlite3_stmt *stmt;
  NSString *sql = [NSString stringWithFormat:@"PRAGMA user_version = %d;", userVersion];
  if (GDTCORSQLCompileSQL(&stmt, db, sql)) {
    if (!GDTCORSQLRunNonQuery(db, stmt)) {
      GDTCORLogError(GDTCORMCEDatabaseError, @"%@", @"There was an error setting user_version");
    }
  }
  GDTCORSQLFinalize(stmt);
}

/** Gets the user_version PRAGMA of the sqlite db.
 *
 * @param db The db to check.
 * @return the int value of the user_version PRAGMA, or -1 if there was an error.
 */
static int GetUserVersion(sqlite3 *db) {
  if (!db) {
    GDTCORLogError(GDTCORMCEDatabaseError, @"%@", @"The database is closed");
    return -1;
  }
  __block int userVersion = -1;
  sqlite3_stmt *stmt;
  if (GDTCORSQLCompileSQL(&stmt, db, @"PRAGMA user_version;")) {
    GDTCORSQLRunQuery(db, stmt, ^(sqlite3_stmt *stmt) {
      userVersion = sqlite3_column_int(stmt, 0);
    });
  }
  GDTCORSQLFinalize(stmt);
  return userVersion;
}

/** Executes a non-query SQL statement. Non-queries have no result set.
 *
 * @param db The db to operate on.
 * @param bindings The objects to bind to the params of the statement. Bindings to a statement are
 * 1-based.
 * @param sql The SQL string to execute.
 * @param stmtCache The statement cache.
 * @param cacheStmt YES if the resulting stmt should be stored in the stmtCache.
 * @return YES if running the non-query was successful.
 */
static BOOL RunNonQuery(sqlite3 *db,
                        NSDictionary<NSNumber *, NSString *> *_Nullable bindings,
                        NSString *sql,
                        CFMutableDictionaryRef stmtCache,
                        BOOL cacheStmt) {
  if (!db) {
    GDTCORLogError(GDTCORMCEDatabaseError, @"%@", @"The database is closed");
    return NO;
  }
  if (sql == nil || sql.length == 0) {
    GDTCORLogError(GDTCORMCEDatabaseError, @"%@", @"SQL string was empty");
    return NO;
  }
  if (stmtCache == nil) {
    GDTCORLogError(GDTCORMCEDatabaseError, @"%@", @"Statement cache needs to be non-nil");
    return NO;
  }
  sqlite3_stmt *stmt =
      (sqlite3_stmt *)CFDictionaryGetValue(stmtCache, (__bridge const void *)(sql));
  if (stmt == NULL) {
    if (GDTCORSQLCompileSQL(&stmt, db, sql)) {
      if (stmtCache != nil && cacheStmt) {
        CFDictionaryAddValue(stmtCache, (__bridge const void *)(sql), stmt);
      }
    } else {
      GDTCORLogError(GDTCORMCEDatabaseError, @"SQL did not compile: %@", sql);
      return NO;
    }
  }
  [bindings enumerateKeysAndObjectsUsingBlock:^(NSNumber *_Nonnull key, NSString *_Nonnull obj,
                                                BOOL *_Nonnull stop) {
    GDTCORSQLBindObjectToParam(stmt, key.intValue, obj);
  }];
  BOOL result = GDTCORSQLRunNonQuery(db, stmt);
  if (cacheStmt) {
    GDTCORSQLReset(stmt);
  } else {
    GDTCORSQLFinalize(stmt);
  }
  return result;
}

/** Executes a query SQL statement. Queries possibly have a result set.
 *
 * @param db The db to operate on.
 * @param bindings The objects to bind to the params of the statement. Bindings to a statement are
 * 1-based.
 * @param eachRow A blcok that is ran on each row of the result set.
 * @param sql The SQL string to execute.
 * @param stmtCache The statement cache.
 * @param cacheStmt YES if the resulting stmt should be stored in the stmtCache.
 * @return YES if running the non-query was successful.
 */
static BOOL RunQuery(sqlite3 *db,
                     NSDictionary<NSNumber *, NSString *> *_Nullable bindings,
                     GDTCORSqliteRowResultBlock eachRow,
                     NSString *sql,
                     CFMutableDictionaryRef stmtCache,
                     BOOL cacheStmt) {
  if (!db) {
    GDTCORLogError(GDTCORMCEDatabaseError, @"%@", @"The database is closed");
    return NO;
  }
  if (sql == nil || sql.length == 0) {
    GDTCORLogError(GDTCORMCEDatabaseError, @"%@", @"SQL string was empty");
    return NO;
  }
  if (stmtCache == nil) {
    GDTCORLogError(GDTCORMCEDatabaseError, @"%@", @"Statement cache needs to be non-nil");
    return NO;
  }
  sqlite3_stmt *stmt =
      (sqlite3_stmt *)CFDictionaryGetValue(stmtCache, (__bridge const void *)(sql));
  if (stmt == NULL) {
    if (GDTCORSQLCompileSQL(&stmt, db, sql)) {
      if (stmtCache != nil && cacheStmt) {
        CFDictionaryAddValue(stmtCache, (__bridge const void *)(sql), stmt);
      }
    } else {
      GDTCORLogError(GDTCORMCEDatabaseError, @"SQL did not compile: %@", sql);
      return NO;
    }
  }
  [bindings enumerateKeysAndObjectsUsingBlock:^(NSNumber *_Nonnull key, NSString *_Nonnull obj,
                                                BOOL *_Nonnull stop) {
    GDTCORSQLBindObjectToParam(stmt, key.intValue, obj);
  }];
  BOOL result = GDTCORSQLRunQuery(db, stmt, eachRow);
  if (cacheStmt) {
    GDTCORSQLReset(stmt);
  } else {
    GDTCORSQLFinalize(stmt);
  }
  return result;
}

/** Runs a series of migrations, setting the user_version PRAGMA to the highest version number.
 *
 * @param db The db to operate on.
 * @param migrations The map of user_version numbers to the SQL statement needed to update to that
 *   version.
 * @param stmtCache The statement cache.
 */
static void RunMigrations(sqlite3 *db,
                          NSDictionary<NSNumber *, NSString *> *migrations,
                          CFMutableDictionaryRef stmtCache) {
  if (!db) {
    GDTCORLogError(GDTCORMCEDatabaseError, @"%@", @"The database is closed");
    return;
  }
  int userVersion = GetUserVersion(db);
  __block int newUserVersion = userVersion;
  [migrations enumerateKeysAndObjectsUsingBlock:^(NSNumber *_Nonnull key, NSString *_Nonnull obj,
                                                  BOOL *_Nonnull stop) {
    if (key.intValue > newUserVersion) {
      if (RunNonQuery(db, nil, obj, stmtCache, NO)) {
        newUserVersion = key.intValue;
      } else {
        GDTCORLogError(GDTCORMCEDatabaseError, @"%@", @"Migration failed: version:%@ statement:%@",
                       key, obj);
      }
    }
  }];

  if (newUserVersion != userVersion) {
    SetUserVersion(db, newUserVersion);
  }
}

#pragma mark - GDTCORDatabase

@implementation GDTCORDatabase {
  /** The sqlite database. */
  sqlite3 *_db;
}

- (nullable instancetype)initWithURL:(nullable NSURL *)dbFileURL
                 migrationStatements:
                     (nonnull NSDictionary<NSNumber *, NSString *> *)migrationStatements {
  // Only 1 instance per file is allowed. Return nil if one is already open.
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instancesToDBFiles = [[NSMutableDictionary alloc] init];
  });
  __block GDTCORDatabase *extantDB;
  dispatch_barrier_sync(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
    extantDB = instancesToDBFiles[dbFileURL.path];
  });
  if (extantDB) {
    return nil;
  }

  // Create an instance.
  self = [super init];
  if (self) {
    NSString *dbPath = dbFileURL ? dbFileURL.path : @":memory:";
    if (!GDTCORSQLOpenDB(&_db, dbPath)) {
      return nil;
    }
    _dbQueue = dispatch_queue_create("com.google.GDTCORDatabase", DISPATCH_QUEUE_SERIAL);
    _fileURL = dbFileURL;
    _stmtCache =
        CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, NULL);
    dispatch_async(_dbQueue, ^{
      RunMigrations(self->_db, [migrationStatements copy], self -> _stmtCache);
    });
    dispatch_barrier_sync(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
      instancesToDBFiles[dbPath] = self;
    });
  }
  return self;
}

- (void)dealloc {
  [self close];
}

- (BOOL)open {
  if (_db == NULL) {
    return GDTCORSQLOpenDB(&_db, _fileURL ? _fileURL.path : @":memory:");
  }
  GDTCORLogWarning(GDTCORMCWDatabaseWarning, @"Database already open: %@", _fileURL);
  return NO;
}

- (BOOL)close {
  if (_dbQueue != nil && _db != NULL) {
    dispatch_sync(_dbQueue, ^{
      GDTCORSQLCloseDB(_db);
      _db = NULL;
    });
    if (_fileURL) {
      dispatch_barrier_sync(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        [instancesToDBFiles removeObjectForKey:_fileURL.path];
      });
    }
    return YES;
  }
  return NO;
}

- (void)setUserVersion:(int)userVersion {
  dispatch_async(_dbQueue, ^{
    SetUserVersion(self->_db, userVersion);
  });
}

- (int)userVersion {
  __block int userVersion = -1;
  dispatch_sync(_dbQueue, ^{
    userVersion = GetUserVersion(self->_db);
  });
  return userVersion;
}

- (BOOL)runNonQuery:(NSString *)sql
           bindings:(NSDictionary<NSNumber *, NSString *> *)bindings
          cacheStmt:(BOOL)cacheStmt {
  __block BOOL returnStatus = NO;
  dispatch_sync(_dbQueue, ^{
    returnStatus = RunNonQuery(_db, bindings, sql, self->_stmtCache, cacheStmt);
  });
  return returnStatus;
}

- (BOOL)runQuery:(NSString *)sql
        bindings:(NSDictionary<NSNumber *, NSString *> *)bindings
         eachRow:(GDTCORSqliteRowResultBlock)eachRow
       cacheStmt:(BOOL)cacheStmt {
  __block BOOL returnStatus = NO;
  dispatch_sync(_dbQueue, ^{
    returnStatus = RunQuery(self->_db, bindings, eachRow, sql, self->_stmtCache, cacheStmt);
  });
  return returnStatus;
}

@end
