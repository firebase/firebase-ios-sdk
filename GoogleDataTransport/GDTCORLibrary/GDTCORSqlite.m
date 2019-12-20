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

#import "GDTCORLibrary/Public/GDTCORSqlite.h"

#import <GoogleDataTransport/GDTCORConsoleLogger.h>

#pragma mark - Private helper functions

/** Runs the given block and compares against SQLITE_OK. A convenience function for
 * GDTCORSQLBindObjectToParam.
 *
 * @param bindBlock The binding block to check.
 * @return YES if running the binding block was successful, NO otherwise.
 */
static BOOL BindCheck(SQLITE_API int (^bindBlock)(void)) {
  if (bindBlock && bindBlock() != SQLITE_OK) {
    GDTCORLogError(GDTCORMCEDatabaseError, @"%@", @"Error binding an object.");
    return NO;
  }
  return YES;
}

#pragma mark - Public functions

BOOL GDTCORSQLOpenDB(sqlite3 **db, NSString *path) {
  if (path == nil || path.length == 0) {
    GDTCORLogError(GDTCORMCEDatabaseError, @"%@", @"A filename for the sqlite db must not be nil");
    return NO;
  }

  int flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FILEPROTECTION_COMPLETE |
              SQLITE_OPEN_FULLMUTEX;
  return sqlite3_open_v2(path.UTF8String, db, flags, NULL) == SQLITE_OK;
}

BOOL GDTCORSQLCloseDB(sqlite3 *db) {
  return sqlite3_close(db) == SQLITE_OK;
}

BOOL GDTCORSQLCompileSQL(sqlite3_stmt **stmt, sqlite3 *db, NSString *statement) {
  if (statement == nil || statement.length <= 0) {
    GDTCORLogError(GDTCORMCEDatabaseError, @"%@", @"The statement was empty/nil.");
    return NO;
  }

  if (sqlite3_prepare_v2(db, statement.UTF8String, -1, stmt, NULL) != SQLITE_OK) {
    const char *errMsg = sqlite3_errmsg(db);
    if (errMsg) {
      GDTCORLogError(GDTCORMCEDatabaseError, @"Failed to compile statement: %s\nError: %s",
                     statement.UTF8String, errMsg);
      return NO;
    }
  }
  return YES;
}

BOOL GDTCORSQLReset(sqlite3_stmt *stmt) {
  return sqlite3_reset(stmt) == SQLITE_OK;
}

BOOL GDTCORSQLFinalize(sqlite3_stmt *stmt) {
  return sqlite3_finalize(stmt) == SQLITE_OK;
}

BOOL GDTCORSQLRunNonQuery(sqlite3 *db, sqlite3_stmt *stmt) {
  if (stmt == NULL) {
    GDTCORLogError(GDTCORMCEDatabaseError, @"%@", @"Cannot run a NULL statement.");
    return NO;
  }

  if (sqlite3_step(stmt) != SQLITE_DONE) {
    const char *errMsg = sqlite3_errmsg(db);
    if (errMsg) {
      GDTCORLogError(GDTCORMCEDatabaseError, @"%@", @"error running statement: %s", errMsg);
    }
    return NO;
  }
  return YES;
}

BOOL GDTCORSQLRunQuery(sqlite3 *db, sqlite3_stmt *stmt, GDTCORSqliteRowResultBlock eachRow) {
  if (stmt == NULL) {
    GDTCORLogError(GDTCORMCEDatabaseError, @"%@", @"Cannot run a NULL statement.");
    return NO;
  }
  if (eachRow == nil) {
    GDTCORLogError(GDTCORMCEDatabaseError, @"%@", @"Please provide a per-row block to run.");
    return NO;
  }

  while (sqlite3_step(stmt) == SQLITE_ROW) {
    eachRow(stmt);
  }
  return YES;
}

BOOL GDTCORSQLBindObjectToParam(sqlite3_stmt *stmt, int column, id object) {
  if (object == nil || [object isKindOfClass:[NSNull class]]) {
    return BindCheck(^int {
      return sqlite3_bind_null(stmt, column);
    });
  } else if ([object isKindOfClass:[NSString class]]) {
    return BindCheck(^int {
      return sqlite3_bind_text(stmt, column, ((NSString *)object).UTF8String, -1, SQLITE_TRANSIENT);
    });
  } else if ([object isKindOfClass:[NSData class]]) {
    const void *bytes = [object bytes];
    if (!bytes) {
      bytes = "";
    }
    return BindCheck(^int {
      return sqlite3_bind_blob(stmt, column, bytes, (int)[object length], SQLITE_TRANSIENT);
    });
  } else if ([object isKindOfClass:[NSNumber class]]) {
    if (strcmp([object objCType], @encode(BOOL)) == 0) {
      return BindCheck(^int {
        return sqlite3_bind_int(stmt, column, ([object boolValue] ? 1 : 0));
      });
    } else if (strcmp([object objCType], @encode(char)) == 0) {
      return BindCheck(^int {
        return sqlite3_bind_int(stmt, column, [object charValue]);
      });
    } else if (strcmp([object objCType], @encode(unsigned char)) == 0) {
      return BindCheck(^int {
        return sqlite3_bind_int(stmt, column, [object unsignedCharValue]);
      });
    } else if (strcmp([object objCType], @encode(short)) == 0) {
      return BindCheck(^int {
        return sqlite3_bind_int(stmt, column, [object shortValue]);
      });
    } else if (strcmp([object objCType], @encode(unsigned short)) == 0) {
      return BindCheck(^int {
        return sqlite3_bind_int(stmt, column, [object unsignedShortValue]);
      });
    } else if (strcmp([object objCType], @encode(int)) == 0) {
      return BindCheck(^int {
        return sqlite3_bind_int(stmt, column, [object intValue]);
      });
    } else if (strcmp([object objCType], @encode(unsigned int)) == 0) {
      return BindCheck(^int {
        return sqlite3_bind_int64(stmt, column, (long long)[object unsignedIntValue]);
      });
    } else if (strcmp([object objCType], @encode(long)) == 0) {
      return BindCheck(^int {
        return sqlite3_bind_int64(stmt, column, [object longValue]);
      });
    } else if (strcmp([object objCType], @encode(unsigned long)) == 0) {
      return BindCheck(^int {
        return sqlite3_bind_int64(stmt, column, (long long)[object unsignedLongValue]);
      });
    } else if (strcmp([object objCType], @encode(long long)) == 0) {
      return BindCheck(^int {
        return sqlite3_bind_int64(stmt, column, [object longLongValue]);
      });
    } else if (strcmp([object objCType], @encode(unsigned long long)) == 0) {
      return BindCheck(^int {
        return sqlite3_bind_int64(stmt, column, (long long)[object unsignedLongLongValue]);
      });
    } else if (strcmp([object objCType], @encode(float)) == 0) {
      return BindCheck(^int {
        return sqlite3_bind_double(stmt, column, [object floatValue]);
      });
    } else if (strcmp([object objCType], @encode(double)) == 0) {
      return BindCheck(^int {
        return sqlite3_bind_double(stmt, column, [object doubleValue]);
      });
    } else {
      return BindCheck(^int {
        return sqlite3_bind_text(stmt, column, [[object description] UTF8String], -1,
                                 SQLITE_TRANSIENT);
      });
    }
  } else {
    GDTCORLogError(GDTCORMCEDatabaseError, @"The type of this object is currently unsupported: %@",
                   [object class]);
    return NO;
  }
}
