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

#import "FirebaseMessaging/Sources/FIRMessagingRmqManager.h"

#import <sqlite3.h>

#import "FirebaseMessaging/Sources/FIRMessagingConstants.h"
#import "FirebaseMessaging/Sources/FIRMessagingDefines.h"
#import "FirebaseMessaging/Sources/FIRMessagingLogger.h"
#import "FirebaseMessaging/Sources/FIRMessagingPersistentSyncMessage.h"
#import "FirebaseMessaging/Sources/FIRMessagingUtilities.h"
#import "FirebaseMessaging/Sources/NSError+FIRMessaging.h"

#ifndef _FIRMessagingRmqLogAndExit
#define _FIRMessagingRmqLogAndExit(stmt, return_value) \
  do {                                                 \
    [self logErrorAndFinalizeStatement:stmt];          \
    return return_value;                               \
  } while (0)
#endif

#ifndef FIRMessagingRmqLogAndReturn
#define FIRMessagingRmqLogAndReturn(stmt)     \
  do {                                        \
    [self logErrorAndFinalizeStatement:stmt]; \
    return;                                   \
  } while (0)
#endif

#ifndef FIRMessaging_MUST_NOT_BE_MAIN_THREAD
#define FIRMessaging_MUST_NOT_BE_MAIN_THREAD()                                        \
  do {                                                                                \
    NSAssert(![NSThread isMainThread], @"Must not be executing on the main thread."); \
  } while (0);
#endif

// table names
NSString *const kTableOutgoingRmqMessages = @"outgoingRmqMessages";
NSString *const kTableLastRmqId = @"lastrmqid";
NSString *const kOldTableS2DRmqIds = @"s2dRmqIds";
NSString *const kTableS2DRmqIds = @"s2dRmqIds_1";

// Used to prevent de-duping of sync messages received both via APNS and MCS.
NSString *const kTableSyncMessages = @"incomingSyncMessages";

static NSString *const kTablePrefix = @"";

// create tables
static NSString *const kCreateTableOutgoingRmqMessages = @"create TABLE IF NOT EXISTS %@%@ "
                                                         @"(_id INTEGER PRIMARY KEY, "
                                                         @"rmq_id INTEGER, "
                                                         @"type INTEGER, "
                                                         @"ts INTEGER, "
                                                         @"data BLOB)";

static NSString *const kCreateTableLastRmqId = @"create TABLE IF NOT EXISTS %@%@ "
                                               @"(_id INTEGER PRIMARY KEY, "
                                               @"rmq_id INTEGER)";

static NSString *const kCreateTableS2DRmqIds = @"create TABLE IF NOT EXISTS %@%@ "
                                               @"(_id INTEGER PRIMARY KEY, "
                                               @"rmq_id TEXT)";

static NSString *const kCreateTableSyncMessages = @"create TABLE IF NOT EXISTS %@%@ "
                                                  @"(_id INTEGER PRIMARY KEY, "
                                                  @"rmq_id TEXT, "
                                                  @"expiration_ts INTEGER, "
                                                  @"apns_recv INTEGER, "
                                                  @"mcs_recv INTEGER)";

static NSString *const kDropTableCommand = @"drop TABLE if exists %@%@";

// table infos
static NSString *const kRmqIdColumn = @"rmq_id";

// Sync message columns
static NSString *const kSyncMessagesColumns = @"rmq_id, expiration_ts, apns_recv, mcs_recv";
// Message time expiration in seconds since 1970
static NSString *const kSyncMessageExpirationTimestampColumn = @"expiration_ts";
static NSString *const kSyncMessageAPNSReceivedColumn = @"apns_recv";
static NSString *const kSyncMessageMCSReceivedColumn = @"mcs_recv";

// Utility to create an NSString from a sqlite3 result code
NSString *_Nonnull FIRMessagingStringFromSQLiteResult(int result) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
  const char *errorStr = sqlite3_errstr(result);
#pragma clang diagnostic pop
  NSString *errorString = [NSString stringWithFormat:@"%d - %s", result, errorStr];
  return errorString;
}

@interface FIRMessagingRmqManager () {
  sqlite3 *_database;
  /// Serial queue for database read/write operations.
  dispatch_queue_t _databaseOperationQueue;
}

@property(nonatomic, readwrite, strong) NSString *databaseName;
@end

@implementation FIRMessagingRmqManager

- (instancetype)initWithDatabaseName:(NSString *)databaseName {
  self = [super init];
  if (self) {
    _databaseOperationQueue =
        dispatch_queue_create("com.google.firebase.messaging.database.rmq", DISPATCH_QUEUE_SERIAL);
    _databaseName = [databaseName copy];
    [self openDatabase];
  }
  return self;
}

- (void)dealloc {
  sqlite3_close(_database);
}

#pragma mark - Sync Messages

- (FIRMessagingPersistentSyncMessage *)querySyncMessageWithRmqID:(NSString *)rmqID {
  __block FIRMessagingPersistentSyncMessage *persistentMessage;
  dispatch_sync(_databaseOperationQueue, ^{
    NSString *queryFormat = @"SELECT %@ FROM %@ WHERE %@ = ?";
    NSString *query =
        [NSString stringWithFormat:queryFormat,
                                   kSyncMessagesColumns,  // SELECT (rmq_id, expiration_ts,
                                                          // apns_recv, mcs_recv)
                                   kTableSyncMessages,    // FROM sync_rmq
                                   kRmqIdColumn           // WHERE rmq_id
    ];

    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(self->_database, [query UTF8String], -1, &stmt, NULL) != SQLITE_OK) {
      [self logError];
      sqlite3_finalize(stmt);
      return;
    }

    if (sqlite3_bind_text(stmt, 1, [rmqID UTF8String], (int)[rmqID length], SQLITE_STATIC) !=
        SQLITE_OK) {
      [self logError];
      sqlite3_finalize(stmt);
      return;
    }

    const int rmqIDColumn = 0;
    const int expirationTimestampColumn = 1;
    const int apnsReceivedColumn = 2;
    const int mcsReceivedColumn = 3;

    int count = 0;

    while (sqlite3_step(stmt) == SQLITE_ROW) {
      NSString *rmqID =
          [NSString stringWithUTF8String:(char *)sqlite3_column_text(stmt, rmqIDColumn)];
      int64_t expirationTimestamp = sqlite3_column_int64(stmt, expirationTimestampColumn);
      BOOL apnsReceived = sqlite3_column_int(stmt, apnsReceivedColumn);
      BOOL mcsReceived = sqlite3_column_int(stmt, mcsReceivedColumn);

      // create a new persistent message
      persistentMessage =
          [[FIRMessagingPersistentSyncMessage alloc] initWithRMQID:rmqID
                                                    expirationTime:expirationTimestamp];
      persistentMessage.apnsReceived = apnsReceived;
      persistentMessage.mcsReceived = mcsReceived;

      count++;
    }
    sqlite3_finalize(stmt);
  });

  return persistentMessage;
}

- (void)deleteExpiredOrFinishedSyncMessages {
  dispatch_async(_databaseOperationQueue, ^{
    int64_t now = FIRMessagingCurrentTimestampInSeconds();
    NSString *deleteSQL = @"DELETE FROM %@ "
                          @"WHERE %@ < %lld OR "   // expirationTime < now
                          @"(%@ = 1 AND %@ = 1)";  // apns_received = 1 AND mcs_received = 1
    NSString *query = [NSString
        stringWithFormat:deleteSQL, kTableSyncMessages, kSyncMessageExpirationTimestampColumn, now,
                         kSyncMessageAPNSReceivedColumn, kSyncMessageMCSReceivedColumn];
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(self->_database, [query UTF8String], -1, &stmt, NULL) != SQLITE_OK) {
      FIRMessagingRmqLogAndReturn(stmt);
    }

    if (sqlite3_step(stmt) != SQLITE_DONE) {
      FIRMessagingRmqLogAndReturn(stmt);
    }

    sqlite3_finalize(stmt);
    int deleteCount = sqlite3_changes(self->_database);
    if (deleteCount > 0) {
      FIRMessagingLoggerDebug(kFIRMessagingMessageCodeSyncMessageManager001,
                              @"Successfully deleted %d sync messages from store", deleteCount);
    }
  });
}

- (void)saveSyncMessageWithRmqID:(NSString *)rmqID expirationTime:(int64_t)expirationTime {
  BOOL apnsReceived = YES;
  BOOL mcsReceived = NO;
  dispatch_async(_databaseOperationQueue, ^{
    NSString *insertFormat = @"INSERT INTO %@ (%@, %@, %@, %@) VALUES (?, ?, ?, ?)";
    NSString *insertSQL =
        [NSString stringWithFormat:insertFormat,
                                   kTableSyncMessages,                     // Table name
                                   kRmqIdColumn,                           // rmq_id
                                   kSyncMessageExpirationTimestampColumn,  // expiration_ts
                                   kSyncMessageAPNSReceivedColumn,         // apns_recv
                                   kSyncMessageMCSReceivedColumn /* mcs_recv */];

    sqlite3_stmt *stmt;

    if (sqlite3_prepare_v2(self->_database, [insertSQL UTF8String], -1, &stmt, NULL) != SQLITE_OK) {
      FIRMessagingRmqLogAndReturn(stmt);
    }

    if (sqlite3_bind_text(stmt, 1, [rmqID UTF8String], (int)[rmqID length], NULL) != SQLITE_OK) {
      FIRMessagingRmqLogAndReturn(stmt);
    }

    if (sqlite3_bind_int64(stmt, 2, expirationTime) != SQLITE_OK) {
      FIRMessagingRmqLogAndReturn(stmt);
    }

    if (sqlite3_bind_int(stmt, 3, apnsReceived ? 1 : 0) != SQLITE_OK) {
      FIRMessagingRmqLogAndReturn(stmt);
    }

    if (sqlite3_bind_int(stmt, 4, mcsReceived ? 1 : 0) != SQLITE_OK) {
      FIRMessagingRmqLogAndReturn(stmt);
    }

    if (sqlite3_step(stmt) != SQLITE_DONE) {
      FIRMessagingRmqLogAndReturn(stmt);
    }
    sqlite3_finalize(stmt);
    FIRMessagingLoggerInfo(kFIRMessagingMessageCodeSyncMessageManager004,
                           @"Added sync message to cache: %@", rmqID);
  });
}

- (void)updateSyncMessageViaAPNSWithRmqID:(NSString *)rmqID {
  dispatch_async(_databaseOperationQueue, ^{
    if (![self updateSyncMessageWithRmqID:rmqID column:kSyncMessageAPNSReceivedColumn value:YES]) {
      FIRMessagingLoggerError(kFIRMessagingMessageCodeSyncMessageManager005,
                              @"Failed to update APNS state for sync message %@", rmqID);
    }
  });
}

- (BOOL)updateSyncMessageWithRmqID:(NSString *)rmqID column:(NSString *)column value:(BOOL)value {
  FIRMessaging_MUST_NOT_BE_MAIN_THREAD();
  NSString *queryFormat = @"UPDATE %@ "     // Table name
                          @"SET %@ = %d "   // column=value
                          @"WHERE %@ = ?";  // condition
  NSString *query = [NSString
      stringWithFormat:queryFormat, kTableSyncMessages, column, value ? 1 : 0, kRmqIdColumn];
  sqlite3_stmt *stmt;

  if (sqlite3_prepare_v2(_database, [query UTF8String], -1, &stmt, NULL) != SQLITE_OK) {
    _FIRMessagingRmqLogAndExit(stmt, NO);
  }

  if (sqlite3_bind_text(stmt, 1, [rmqID UTF8String], (int)[rmqID length], NULL) != SQLITE_OK) {
    _FIRMessagingRmqLogAndExit(stmt, NO);
  }

  if (sqlite3_step(stmt) != SQLITE_DONE) {
    _FIRMessagingRmqLogAndExit(stmt, NO);
  }

  sqlite3_finalize(stmt);
  return YES;
}

#pragma mark - Database

- (NSString *)pathForDatabase {
  return [[self class] pathForDatabaseWithName:_databaseName];
}

+ (NSString *)pathForDatabaseWithName:(NSString *)databaseName {
  NSString *dbNameWithExtension = [NSString stringWithFormat:@"%@.sqlite", databaseName];
  NSArray *paths =
      NSSearchPathForDirectoriesInDomains(FIRMessagingSupportedDirectory(), NSUserDomainMask, YES);
  NSArray *components = @[ paths.lastObject, kFIRMessagingSubDirectoryName, dbNameWithExtension ];
  return [NSString pathWithComponents:components];
}

- (void)createTableWithName:(NSString *)tableName command:(NSString *)command {
  FIRMessaging_MUST_NOT_BE_MAIN_THREAD();
  char *error = NULL;
  NSString *createDatabase = [NSString stringWithFormat:command, kTablePrefix, tableName];
  if (sqlite3_exec(self->_database, [createDatabase UTF8String], NULL, NULL, &error) != SQLITE_OK) {
    // remove db before failing
    [self removeDatabase];
    NSString *sqlError;
    if (error != NULL) {
      sqlError = [NSString stringWithCString:error encoding:NSUTF8StringEncoding];
      sqlite3_free(error);
    } else {
      sqlError = @"(null)";
    }
    NSString *errorMessage =
        [NSString stringWithFormat:@"Couldn't create table: %@ with command: %@ error: %@",
                                   kCreateTableOutgoingRmqMessages, createDatabase, sqlError];
    FIRMessagingLoggerError(kFIRMessagingMessageCodeRmq2PersistentStoreErrorCreatingTable, @"%@",
                            errorMessage);
    NSAssert(NO, errorMessage);
  }
}

- (void)dropTableWithName:(NSString *)tableName {
  FIRMessaging_MUST_NOT_BE_MAIN_THREAD();
  char *error;
  NSString *dropTableSQL = [NSString stringWithFormat:kDropTableCommand, kTablePrefix, tableName];
  if (sqlite3_exec(self->_database, [dropTableSQL UTF8String], NULL, NULL, &error) != SQLITE_OK) {
    FIRMessagingLoggerError(kFIRMessagingMessageCodeRmq2PersistentStore002,
                            @"Failed to remove table %@", tableName);
  }
}

- (void)removeDatabase {
  // Ensure database is removed in a sync queue as this sometimes makes test have race conditions.
  dispatch_async(_databaseOperationQueue, ^{
    NSString *path = [self pathForDatabase];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
  });
}

- (void)createTable {
  [self createTableWithName:kTableOutgoingRmqMessages command:kCreateTableOutgoingRmqMessages];
  [self createTableWithName:kTableLastRmqId command:kCreateTableLastRmqId];
  [self createTableWithName:kTableS2DRmqIds command:kCreateTableS2DRmqIds];
}

- (void)openDatabase {
  dispatch_async(_databaseOperationQueue, ^{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [self pathForDatabase];

    BOOL didOpenDatabase = YES;
    if (![fileManager fileExistsAtPath:path]) {
      // We've to separate between different versions here because of backward compatibility issues.
      int flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE;
#ifdef SQLITE_OPEN_FILEPROTECTION_NONE
      flags |= SQLITE_OPEN_FILEPROTECTION_NONE;
#endif
      int result = sqlite3_open_v2([path UTF8String], &self->_database, flags, NULL);
      if (result != SQLITE_OK) {
        NSString *errorString = FIRMessagingStringFromSQLiteResult(result);
        NSString *errorMessage = [NSString
            stringWithFormat:@"Could not open existing RMQ database at path %@, error: %@", path,
                             errorString];
        FIRMessagingLoggerError(kFIRMessagingMessageCodeRmq2PersistentStoreErrorOpeningDatabase,
                                @"%@", errorMessage);
        NSAssert(NO, errorMessage);
        return;
      }
      [self createTable];
    } else {
      // The file exists, try to open it. If it fails, it might be corrupt.
      int flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE;
#ifdef SQLITE_OPEN_FILEPROTECTION_NONE
      flags |= SQLITE_OPEN_FILEPROTECTION_NONE;
#endif
      int result = sqlite3_open_v2([path UTF8String], &self->_database, flags, NULL);

      // If opening the database failed, it might be corrupt. Try to recover by deleting and
      // recreating it.
      if (result != SQLITE_OK) {
        if (result == SQLITE_CANTOPEN) {
          FIRMessagingLoggerWarn(
              kFIRMessagingMessageCodeRmq2PersistentStoreErrorOpeningDatabase,
              @"Could not open RMQ database at path: %@. Will delete and try to recreate it.",
              path);
          NSError *removeError;
          if (![[NSFileManager defaultManager] removeItemAtPath:path error:&removeError]) {
            FIRMessagingLoggerWarn(kFIRMessagingMessageCodeRmq2PersistentStoreErrorOpeningDatabase,
                                   @"Failed to delete database for recovery at %@: %@", path,
                                   removeError);
          }
          // After deleting, try to open it again.
          result = sqlite3_open_v2([path UTF8String], &self->_database, flags, NULL);
          // If it still fails after the recovery attempt, then assert and crash.
          if (result != SQLITE_OK) {
            NSString *errorString = FIRMessagingStringFromSQLiteResult(result);
            NSString *errorMessage = [NSString
                stringWithFormat:@"Could not open or create RMQ database at path %@, error: %@",
                                 path, errorString];
            FIRMessagingLoggerError(kFIRMessagingMessageCodeRmq2PersistentStoreErrorOpeningDatabase,
                                    @"%@", errorMessage);
            NSAssert(NO, errorMessage);
            didOpenDatabase = NO;  // Still failed, so indicate database did not open.
          } else {
            // Successfully recreated after an open failure, so treat as a new database for table
            // creation.
            didOpenDatabase = YES;  // Indicate successful opening after recreation.
            [self createTable];
          }
        } else {
          NSString *errorString = FIRMessagingStringFromSQLiteResult(result);
          NSString *errorMessage =
              [NSString stringWithFormat:
                            @"Could not open RMQ database at path %@, error: %@. Won't delete the "
                            @"database as it is not a corrupt database error.",
                            path, errorString];
          FIRMessagingLoggerError(kFIRMessagingMessageCodeRmq2PersistentStoreErrorOpeningDatabase,
                                  @"%@", errorMessage);
          NSAssert(NO, errorMessage);
          didOpenDatabase = NO;  // Still failed, so indicate database did not open.
        }
      } else {
        [self updateDBWithStringRmqID];
      }
    }

    if (didOpenDatabase) {
      [self createTableWithName:kTableSyncMessages command:kCreateTableSyncMessages];
    }
  });
}

- (void)updateDBWithStringRmqID {
  dispatch_async(_databaseOperationQueue, ^{
    [self createTableWithName:kTableS2DRmqIds command:kCreateTableS2DRmqIds];
    [self dropTableWithName:kOldTableS2DRmqIds];
  });
}

#pragma mark - Private

- (NSString *)lastErrorMessage {
  return [NSString stringWithFormat:@"%s", sqlite3_errmsg(_database)];
}

- (int)lastErrorCode {
  return sqlite3_errcode(_database);
}

- (void)logError {
  FIRMessagingLoggerError(kFIRMessagingMessageCodeRmq2PersistentStore006,
                          @"Error: code (%d) message: %@", [self lastErrorCode],
                          [self lastErrorMessage]);
}

- (void)logErrorAndFinalizeStatement:(sqlite3_stmt *)stmt {
  [self logError];
  sqlite3_finalize(stmt);
}

- (dispatch_queue_t)databaseOperationQueue {
  return _databaseOperationQueue;
}

@end
