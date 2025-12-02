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
static NSString *const kDataColumn = @"data";
static NSString *const kProtobufTagColumn = @"type";
static NSString *const kIdColumn = @"_id";

static NSString *const kOutgoingRmqMessagesColumns = @"rmq_id, type, data";

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
// map the category of an outgoing message with the number of messages for that category
// should always have two keys -- the app, gcm
@property(nonatomic, readwrite, strong) NSMutableDictionary *outstandingMessages;

// Outgoing RMQ persistent id
@property(nonatomic, readwrite, assign) int64_t rmqId;
@end

@implementation FIRMessagingRmqManager

- (instancetype)initWithDatabaseName:(NSString *)databaseName {
  self = [super init];
  if (self) {
    _databaseOperationQueue =
        dispatch_queue_create("com.google.firebase.messaging.database.rmq", DISPATCH_QUEUE_SERIAL);
    _databaseName = [databaseName copy];
    [self openDatabase];
    _outstandingMessages = [NSMutableDictionary dictionaryWithCapacity:2];
    _rmqId = -1;
  }
  return self;
}

- (void)dealloc {
  sqlite3_close(_database);
}

#pragma mark - RMQ ID

- (void)loadRmqId {
  if (self.rmqId >= 0) {
    return;  // already done
  }

  [self loadInitialOutgoingPersistentId];
  if (self.outstandingMessages.count) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeRmqManager000, @"Outstanding categories %ld",
                            _FIRMessaging_UL(self.outstandingMessages.count));
  }
}

/**
 * Initialize the 'initial RMQ':
 * - max ID of any message in the queue
 * - if the queue is empty, stored value in separate DB.
 *
 * Stream acks will remove from RMQ, when we remove the highest message we keep track
 * of its ID.
 */
- (void)loadInitialOutgoingPersistentId {
  // we shouldn't always trust the lastRmqId stored in the LastRmqId table, because
  // we only save to the LastRmqId table once in a while (after getting the lastRmqId sent
  // by the server after reconnect, and after getting a rmq ack from the server). The
  // rmq message with the highest rmq id tells the real story, so check against that first.

  __block int64_t rmqId;
  dispatch_sync(_databaseOperationQueue, ^{
    rmqId = [self queryHighestRmqId];
  });
  if (rmqId == 0) {
    dispatch_sync(_databaseOperationQueue, ^{
      rmqId = [self queryLastRmqId];
    });
  }
  self.rmqId = rmqId + 1;
}

/**
 * This is called when we delete the largest outgoing message from queue.
 */
- (void)saveLastOutgoingRmqId:(int64_t)rmqID {
  dispatch_async(_databaseOperationQueue, ^{
    NSString *queryFormat = @"INSERT OR REPLACE INTO %@ (%@, %@) VALUES (?, ?)";
    NSString *query = [NSString stringWithFormat:queryFormat,
                                                 kTableLastRmqId,           // table
                                                 kIdColumn, kRmqIdColumn];  // columns
    sqlite3_stmt *statement;
    if (sqlite3_prepare_v2(self->_database, [query UTF8String], -1, &statement, NULL) !=
        SQLITE_OK) {
      FIRMessagingRmqLogAndReturn(statement);
    }
    if (sqlite3_bind_int(statement, 1, 1) != SQLITE_OK) {
      FIRMessagingRmqLogAndReturn(statement);
    }
    if (sqlite3_bind_int64(statement, 2, rmqID) != SQLITE_OK) {
      FIRMessagingRmqLogAndReturn(statement);
    }
    if (sqlite3_step(statement) != SQLITE_DONE) {
      FIRMessagingRmqLogAndReturn(statement);
    }
    sqlite3_finalize(statement);
  });
}

- (void)saveS2dMessageWithRmqId:(NSString *)rmqId {
  dispatch_async(_databaseOperationQueue, ^{
    NSString *insertFormat = @"INSERT INTO %@ (%@) VALUES (?)";
    NSString *insertSQL = [NSString stringWithFormat:insertFormat, kTableS2DRmqIds, kRmqIdColumn];
    sqlite3_stmt *insert_statement;
    if (sqlite3_prepare_v2(self->_database, [insertSQL UTF8String], -1, &insert_statement, NULL) !=
        SQLITE_OK) {
      FIRMessagingRmqLogAndReturn(insert_statement);
    }
    if (sqlite3_bind_text(insert_statement, 1, [rmqId UTF8String], (int)[rmqId length],
                          SQLITE_STATIC) != SQLITE_OK) {
      FIRMessagingRmqLogAndReturn(insert_statement);
    }
    if (sqlite3_step(insert_statement) != SQLITE_DONE) {
      FIRMessagingRmqLogAndReturn(insert_statement);
    }
    sqlite3_finalize(insert_statement);
  });
}

#pragma mark - Query

- (int64_t)queryHighestRmqId {
  NSString *queryFormat = @"SELECT %@ FROM %@ ORDER BY %@ DESC LIMIT %d";
  NSString *query = [NSString stringWithFormat:queryFormat,
                                               kRmqIdColumn,               // column
                                               kTableOutgoingRmqMessages,  // table
                                               kRmqIdColumn,               // order by column
                                               1];                         // limit

  sqlite3_stmt *statement;
  int64_t highestRmqId = 0;
  if (sqlite3_prepare_v2(_database, [query UTF8String], -1, &statement, NULL) != SQLITE_OK) {
    _FIRMessagingRmqLogAndExit(statement, highestRmqId);
  }
  if (sqlite3_step(statement) == SQLITE_ROW) {
    highestRmqId = sqlite3_column_int64(statement, 0);
  }
  sqlite3_finalize(statement);
  return highestRmqId;
}

- (int64_t)queryLastRmqId {
  NSString *queryFormat = @"SELECT %@ FROM %@ ORDER BY %@ DESC LIMIT %d";
  NSString *query = [NSString stringWithFormat:queryFormat,
                                               kRmqIdColumn,     // column
                                               kTableLastRmqId,  // table
                                               kRmqIdColumn,     // order by column
                                               1];               // limit

  sqlite3_stmt *statement;
  int64_t lastRmqId = 0;
  if (sqlite3_prepare_v2(_database, [query UTF8String], -1, &statement, NULL) != SQLITE_OK) {
    _FIRMessagingRmqLogAndExit(statement, lastRmqId);
  }
  if (sqlite3_step(statement) == SQLITE_ROW) {
    lastRmqId = sqlite3_column_int64(statement, 0);
  }
  sqlite3_finalize(statement);
  return lastRmqId;
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
      int result = sqlite3_open_v2([path UTF8String], &self -> _database, flags, NULL);
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
      [self createTableWithName:kTableOutgoingRmqMessages command:kCreateTableOutgoingRmqMessages];

      [self createTableWithName:kTableLastRmqId command:kCreateTableLastRmqId];
      [self createTableWithName:kTableS2DRmqIds command:kCreateTableS2DRmqIds];
    } else {
      // Calling sqlite3_open should create the database, since the file doesn't exist.
      int flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE;
#ifdef SQLITE_OPEN_FILEPROTECTION_NONE
      flags |= SQLITE_OPEN_FILEPROTECTION_NONE;
#endif
      int result = sqlite3_open_v2([path UTF8String], &self -> _database, flags, NULL);
      if (result != SQLITE_OK) {
        NSString *errorString = FIRMessagingStringFromSQLiteResult(result);
        NSString *errorMessage =
            [NSString stringWithFormat:@"Could not create RMQ database at path %@, error: %@", path,
                                       errorString];
        FIRMessagingLoggerError(kFIRMessagingMessageCodeRmq2PersistentStoreErrorCreatingDatabase,
                                @"%@", errorMessage);
        NSAssert(NO, errorMessage);
        didOpenDatabase = NO;
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

- (BOOL)saveMessageWithRmqId:(int64_t)rmqId tag:(int8_t)tag data:(NSData *)data {
  FIRMessaging_MUST_NOT_BE_MAIN_THREAD();
  NSString *insertFormat = @"INSERT INTO %@ (%@, %@, %@) VALUES (?, ?, ?)";
  NSString *insertSQL =
      [NSString stringWithFormat:insertFormat,
                                 kTableOutgoingRmqMessages,  // table
                                 kRmqIdColumn, kProtobufTagColumn, kDataColumn /* columns */];
  sqlite3_stmt *insert_statement;
  if (sqlite3_prepare_v2(self->_database, [insertSQL UTF8String], -1, &insert_statement, NULL) !=
      SQLITE_OK) {
    _FIRMessagingRmqLogAndExit(insert_statement, NO);
  }
  if (sqlite3_bind_int64(insert_statement, 1, rmqId) != SQLITE_OK) {
    _FIRMessagingRmqLogAndExit(insert_statement, NO);
  }
  if (sqlite3_bind_int(insert_statement, 2, tag) != SQLITE_OK) {
    _FIRMessagingRmqLogAndExit(insert_statement, NO);
  }
  if (sqlite3_bind_blob(insert_statement, 3, [data bytes], (int)[data length], NULL) != SQLITE_OK) {
    _FIRMessagingRmqLogAndExit(insert_statement, NO);
  }
  if (sqlite3_step(insert_statement) != SQLITE_DONE) {
    _FIRMessagingRmqLogAndExit(insert_statement, NO);
  }

  sqlite3_finalize(insert_statement);

  return YES;
}

- (void)deleteMessagesFromTable:(NSString *)tableName withRmqIds:(NSArray *)rmqIds {
  dispatch_async(_databaseOperationQueue, ^{
    BOOL isRmqIDString = NO;
    // RmqID is a string only for outgoing messages
    if ([tableName isEqualToString:kTableS2DRmqIds] ||
        [tableName isEqualToString:kTableSyncMessages]) {
      isRmqIDString = YES;
    }

    NSMutableString *delete =
        [NSMutableString stringWithFormat:@"DELETE FROM %@ WHERE ", tableName];

    NSString *toDeleteArgument = [NSString stringWithFormat:@"%@ = ? OR ", kRmqIdColumn];

    int toDelete = (int)[rmqIds count];
    if (toDelete == 0) {
      return;
    }
    int maxBatchSize = 100;
    int start = 0;
    int deleteCount = 0;
    while (start < toDelete) {
      // construct the WHERE argument
      int end = MIN(start + maxBatchSize, toDelete);
      NSMutableString *whereArgument = [NSMutableString string];
      for (int i = start; i < end; i++) {
        [whereArgument appendString:toDeleteArgument];
      }
      // remove the last * OR * from argument
      NSRange range = NSMakeRange([whereArgument length] - 4, 4);
      [whereArgument deleteCharactersInRange:range];
      NSString *deleteQuery = [NSString stringWithFormat:@"%@ %@", delete, whereArgument];

      // sqlite update
      sqlite3_stmt *delete_statement;
      if (sqlite3_prepare_v2(self->_database, [deleteQuery UTF8String], -1, &delete_statement,
                             NULL) != SQLITE_OK) {
        FIRMessagingRmqLogAndReturn(delete_statement);
      }

      // bind values
      int rmqIndex = 0;
      int placeholderIndex = 1;          // placeholders in sqlite3 start with 1
      for (NSString *rmqId in rmqIds) {  // objectAtIndex: is O(n) -- would make it slow
        if (rmqIndex < start) {
          rmqIndex++;
          continue;
        } else if (rmqIndex >= end) {
          break;
        } else {
          if (isRmqIDString) {
            if (sqlite3_bind_text(delete_statement, placeholderIndex, [rmqId UTF8String],
                                  (int)[rmqId length], SQLITE_STATIC) != SQLITE_OK) {
              FIRMessagingLoggerDebug(kFIRMessagingMessageCodeRmq2PersistentStore003,
                                      @"Failed to bind rmqID %@", rmqId);
              FIRMessagingLoggerError(kFIRMessagingMessageCodeSyncMessageManager007,
                                      @"Failed to delete sync message %@", rmqId);
              continue;
            }
          } else {
            int64_t rmqIdValue = [rmqId longLongValue];
            sqlite3_bind_int64(delete_statement, placeholderIndex, rmqIdValue);
          }
          placeholderIndex++;
        }
        rmqIndex++;
        FIRMessagingLoggerInfo(kFIRMessagingMessageCodeSyncMessageManager008,
                               @"Successfully deleted sync message from cache %@", rmqId);
      }
      if (sqlite3_step(delete_statement) != SQLITE_DONE) {
        FIRMessagingRmqLogAndReturn(delete_statement);
      }
      sqlite3_finalize(delete_statement);
      deleteCount += sqlite3_changes(self->_database);
      start = end;
    }

    // if we are here all of our sqlite queries should have succeeded
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeRmq2PersistentStore004,
                            @"Trying to delete %d s2D ID's, successfully deleted %d", toDelete,
                            deleteCount);
  });
}

- (int64_t)nextRmqId {
  return ++self.rmqId;
}

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
