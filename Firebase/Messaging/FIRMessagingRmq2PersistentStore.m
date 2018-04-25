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

#import "FIRMessagingRmq2PersistentStore.h"

#import "sqlite3.h"

#import "Protos/GtalkCore.pbobjc.h"

#import "FIRMessagingConstants.h"
#import "FIRMessagingDefines.h"
#import "FIRMessagingLogger.h"
#import "FIRMessagingPersistentSyncMessage.h"
#import "FIRMessagingUtilities.h"
#import "NSError+FIRMessaging.h"

#ifndef _FIRMessagingRmqLogAndExit
#define _FIRMessagingRmqLogAndExit(stmt, return_value)   \
do {                              \
[self logErrorAndFinalizeStatement:stmt];  \
return return_value; \
} while(0)
#endif

typedef enum : NSUInteger {
  FIRMessagingRmqDirectoryUnknown,
  FIRMessagingRmqDirectoryDocuments,
  FIRMessagingRmqDirectoryApplicationSupport,
} FIRMessagingRmqDirectory;

static NSString *const kFCMRmqStoreTag = @"FIRMessagingRmqStore:";

// table names
NSString *const kTableOutgoingRmqMessages = @"outgoingRmqMessages";
NSString *const kTableLastRmqId = @"lastrmqid";
NSString *const kOldTableS2DRmqIds = @"s2dRmqIds";
NSString *const kTableS2DRmqIds = @"s2dRmqIds_1";

// Used to prevent de-duping of sync messages received both via APNS and MCS.
NSString *const kTableSyncMessages = @"incomingSyncMessages";

static NSString *const kTablePrefix = @"";

// create tables
static NSString *const kCreateTableOutgoingRmqMessages =
    @"create TABLE IF NOT EXISTS %@%@ "
    @"(_id INTEGER PRIMARY KEY, "
    @"rmq_id INTEGER, "
    @"type INTEGER, "
    @"ts INTEGER, "
    @"data BLOB)";

static NSString *const kCreateTableLastRmqId =
    @"create TABLE IF NOT EXISTS %@%@ "
    @"(_id INTEGER PRIMARY KEY, "
    @"rmq_id INTEGER)";

static NSString *const kCreateTableS2DRmqIds =
    @"create TABLE IF NOT EXISTS %@%@ "
    @"(_id INTEGER PRIMARY KEY, "
    @"rmq_id TEXT)";

static NSString *const kCreateTableSyncMessages =
    @"create TABLE IF NOT EXISTS %@%@ "
    @"(_id INTEGER PRIMARY KEY, "
    @"rmq_id TEXT, "
    @"expiration_ts INTEGER, "
    @"apns_recv INTEGER, "
    @"mcs_recv INTEGER)";

static NSString *const kDropTableCommand =
    @"drop TABLE if exists %@%@";

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

// table data handlers
typedef void(^FCMOutgoingRmqMessagesTableHandler)(int64_t rmqId, int8_t tag, NSData *data);

// Utility to create an NSString from a sqlite3 result code
NSString * _Nonnull FIRMessagingStringFromSQLiteResult(int result) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
  const char *errorStr = sqlite3_errstr(result);
#pragma pop
  NSString *errorString = [NSString stringWithFormat:@"%d - %s", result, errorStr];
  return errorString;
}

@interface FIRMessagingRmq2PersistentStore () {
  sqlite3 *_database;
}

@property(nonatomic, readwrite, strong) NSString *databaseName;
@property(nonatomic, readwrite, assign) FIRMessagingRmqDirectory currentDirectory;

@end

@implementation FIRMessagingRmq2PersistentStore

- (instancetype)initWithDatabaseName:(NSString *)databaseName {
  self = [super init];
  if (self) {
    _databaseName = [databaseName copy];
    BOOL didMoveToApplicationSupport =
        [self moveToApplicationSupportSubDirectory:kFIRMessagingApplicationSupportSubDirectory];

    _currentDirectory = didMoveToApplicationSupport
                            ? FIRMessagingRmqDirectoryApplicationSupport
                            : FIRMessagingRmqDirectoryDocuments;

    [self openDatabase:_databaseName];
  }
  return self;
}

- (void)dealloc {
  sqlite3_close(_database);
}

- (BOOL)moveToApplicationSupportSubDirectory:(NSString *)subDirectoryName {
  NSArray *directoryPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                                NSUserDomainMask, YES);
  NSString *applicationSupportDirPath = directoryPaths.lastObject;
  NSArray *components = @[applicationSupportDirPath, subDirectoryName];
  NSString *subDirectoryPath = [NSString pathWithComponents:components];
  BOOL hasSubDirectory;

  if (![[NSFileManager defaultManager] fileExistsAtPath:subDirectoryPath
                                            isDirectory:&hasSubDirectory]) {
    // Cannot move to non-existent directory
    return NO;
  }

  if ([self doesFileExistInDirectory:FIRMessagingRmqDirectoryDocuments]) {
    NSString *oldPlistPath = [[self class] pathForDatabase:self.databaseName
                                               inDirectory:FIRMessagingRmqDirectoryDocuments];
    NSString *newPlistPath = [[self class]
        pathForDatabase:self.databaseName
            inDirectory:FIRMessagingRmqDirectoryApplicationSupport];

    if ([self doesFileExistInDirectory:FIRMessagingRmqDirectoryApplicationSupport]) {
      // File exists in both Documents and ApplicationSupport, delete the one in Documents
      NSError *deleteError;
      if (![[NSFileManager defaultManager] removeItemAtPath:oldPlistPath error:&deleteError]) {
        FIRMessagingLoggerError(kFIRMessagingMessageCodeRmq2PersistentStore000,
                                @"Failed to delete old copy of %@.sqlite in Documents %@",
                                self.databaseName, deleteError);
      }
      return NO;
    }
    NSError *moveError;
    if (![[NSFileManager defaultManager] moveItemAtPath:oldPlistPath
                                                 toPath:newPlistPath
                                                  error:&moveError]) {
      FIRMessagingLoggerError(kFIRMessagingMessageCodeRmq2PersistentStore001,
                              @"Failed to move file %@ from %@ to %@. Error: %@", self.databaseName,
                              oldPlistPath, newPlistPath, moveError);
      return NO;
    }
  }
  // We moved the file if it existed, otherwise we didn't need to do anything
  return YES;
}

- (BOOL)doesFileExistInDirectory:(FIRMessagingRmqDirectory)directory {
  NSString *path = [[self class] pathForDatabase:self.databaseName inDirectory:directory];
  return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

+ (NSString *)pathForDatabase:(NSString *)dbName inDirectory:(FIRMessagingRmqDirectory)directory {
  NSArray *paths;
  NSArray *components;
  NSString *dbNameWithExtension = [NSString stringWithFormat:@"%@.sqlite", dbName];
  NSString *errorMessage;

  switch (directory) {
    case FIRMessagingRmqDirectoryDocuments:
      paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
      components = @[paths.lastObject, dbNameWithExtension];
      break;

    case FIRMessagingRmqDirectoryApplicationSupport:
      paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                  NSUserDomainMask,
                                                  YES);
      components = @[
                     paths.lastObject,
                     kFIRMessagingApplicationSupportSubDirectory,
                     dbNameWithExtension
                     ];
      break;

    default:
      errorMessage = [NSString stringWithFormat:@"Invalid directory type %lu",
                      (unsigned long)directory];
      FIRMessagingLoggerError(kFIRMessagingMessageCodeRmq2PersistentStoreInvalidRmqDirectory,
                              @"%@",
                              errorMessage);
      NSAssert(NO, errorMessage);
      break;
  }

  return [NSString pathWithComponents:components];
}

- (void)createTableWithName:(NSString *)tableName command:(NSString *)command {
  char *error;
  NSString *createDatabase = [NSString stringWithFormat:command, kTablePrefix, tableName];
  if (sqlite3_exec(_database, [createDatabase UTF8String], NULL, NULL, &error) != SQLITE_OK) {
    // remove db before failing
    [self removeDatabase];
    NSString *errorMessage = [NSString stringWithFormat:@"Couldn't create table: %@ %@",
                              kCreateTableOutgoingRmqMessages,
                              [NSString stringWithCString:error encoding:NSUTF8StringEncoding]];
    FIRMessagingLoggerError(kFIRMessagingMessageCodeRmq2PersistentStoreErrorCreatingTable,
                            @"%@",
                            errorMessage);
    NSAssert(NO, errorMessage);
  }
}

- (void)dropTableWithName:(NSString *)tableName {
  char *error;
  NSString *dropTableSQL = [NSString stringWithFormat:kDropTableCommand, kTablePrefix, tableName];
  if (sqlite3_exec(_database, [dropTableSQL UTF8String], NULL, NULL, &error) != SQLITE_OK) {
    FIRMessagingLoggerError(kFIRMessagingMessageCodeRmq2PersistentStore002,
                            @"Failed to remove table %@", tableName);
  }
}

- (void)removeDatabase {
  NSString *path = [[self class] pathForDatabase:self.databaseName
                                     inDirectory:self.currentDirectory];
  [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

+ (void)removeDatabase:(NSString *)dbName {
  NSString *documentsDirPath = [self pathForDatabase:dbName
                                         inDirectory:FIRMessagingRmqDirectoryDocuments];
  NSString *applicationSupportDirPath =
      [self pathForDatabase:dbName inDirectory:FIRMessagingRmqDirectoryApplicationSupport];
  [[NSFileManager defaultManager] removeItemAtPath:documentsDirPath error:nil];
  [[NSFileManager defaultManager] removeItemAtPath:applicationSupportDirPath error:nil];
}

- (void)openDatabase:(NSString *)dbName {
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSString *path = [[self class] pathForDatabase:dbName inDirectory:self.currentDirectory];

  BOOL didOpenDatabase = YES;
  if (![fileManager fileExistsAtPath:path]) {
    // We've to separate between different versions here because of backwards compatbility issues.
    int result = sqlite3_open([path UTF8String], &_database);
    if (result != SQLITE_OK) {
      NSString *errorString = FIRMessagingStringFromSQLiteResult(result);
      NSString *errorMessage =
          [NSString stringWithFormat:@"Could not open existing RMQ database at path %@, error: %@",
                                     path,
                                     errorString];
      FIRMessagingLoggerError(kFIRMessagingMessageCodeRmq2PersistentStoreErrorOpeningDatabase,
                              @"%@",
                              errorMessage);
      NSAssert(NO, errorMessage);
      didOpenDatabase = NO;
      return;
    }
    [self createTableWithName:kTableOutgoingRmqMessages
                      command:kCreateTableOutgoingRmqMessages];

    [self createTableWithName:kTableLastRmqId command:kCreateTableLastRmqId];
    [self createTableWithName:kTableS2DRmqIds command:kCreateTableS2DRmqIds];
  } else {
    // Calling sqlite3_open should create the database, since the file doesn't exist.
    int result = sqlite3_open([path UTF8String], &_database);
    if (result != SQLITE_OK) {
      NSString *errorString = FIRMessagingStringFromSQLiteResult(result);
      NSString *errorMessage =
          [NSString stringWithFormat:@"Could not create RMQ database at path %@, error: %@",
                                     path,
                                     errorString];
      FIRMessagingLoggerError(kFIRMessagingMessageCodeRmq2PersistentStoreErrorCreatingDatabase,
                              @"%@",
                              errorMessage);
      NSAssert(NO, errorMessage);
      didOpenDatabase = NO;
    } else {
      [self updateDbWithStringRmqID];
    }
  }

  if (didOpenDatabase) {
    [self createTableWithName:kTableSyncMessages command:kCreateTableSyncMessages];
  }
}

- (void)updateDbWithStringRmqID {
  [self createTableWithName:kTableS2DRmqIds command:kCreateTableS2DRmqIds];
  [self dropTableWithName:kOldTableS2DRmqIds];
}

#pragma mark - Insert

- (BOOL)saveUnackedS2dMessageWithRmqId:(NSString *)rmqId {
  NSString *insertFormat = @"INSERT INTO %@ (%@) VALUES (?)";
  NSString *insertSQL = [NSString stringWithFormat:insertFormat,
                         kTableS2DRmqIds,
                         kRmqIdColumn];
  sqlite3_stmt *insert_statement;
  if (sqlite3_prepare_v2(_database, [insertSQL UTF8String], -1, &insert_statement, NULL)
      != SQLITE_OK) {
    _FIRMessagingRmqLogAndExit(insert_statement, NO);
  }
  if (sqlite3_bind_text(insert_statement,
                        1,
                        [rmqId UTF8String],
                        (int)[rmqId length],
                        SQLITE_STATIC) != SQLITE_OK) {
    _FIRMessagingRmqLogAndExit(insert_statement, NO);
  }
  if (sqlite3_step(insert_statement) != SQLITE_DONE) {
    _FIRMessagingRmqLogAndExit(insert_statement, NO);
  }
  sqlite3_finalize(insert_statement);
  return YES;
}

- (BOOL)saveMessageWithRmqId:(int64_t)rmqId
                         tag:(int8_t)tag
                        data:(NSData *)data
                       error:(NSError **)error {
  NSString *insertFormat = @"INSERT INTO %@ (%@, %@, %@) VALUES (?, ?, ?)";
  NSString *insertSQL = [NSString stringWithFormat:insertFormat,
                         kTableOutgoingRmqMessages, // table
                         kRmqIdColumn, kProtobufTagColumn, kDataColumn /* columns */];
  sqlite3_stmt *insert_statement;
  if (sqlite3_prepare_v2(_database, [insertSQL UTF8String], -1, &insert_statement, NULL)
      != SQLITE_OK) {
    if (error) {
      *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s", sqlite3_errmsg(_database)]
                                   code:sqlite3_errcode(_database)
                               userInfo:nil];
    }
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

- (int)deleteMessagesFromTable:(NSString *)tableName
                    withRmqIds:(NSArray *)rmqIds {
  _FIRMessagingDevAssert([tableName isEqualToString:kTableOutgoingRmqMessages] ||
                [tableName isEqualToString:kTableLastRmqId] ||
                [tableName isEqualToString:kTableS2DRmqIds] ||
                [tableName isEqualToString:kTableSyncMessages],
                @"%@: Invalid Table Name %@", kFCMRmqStoreTag, tableName);

  BOOL isRmqIDString = NO;
  // RmqID is a string only for outgoing messages
  if ([tableName isEqualToString:kTableS2DRmqIds] ||
      [tableName isEqualToString:kTableSyncMessages]) {
    isRmqIDString = YES;
  }

  NSMutableString *delete = [NSMutableString stringWithFormat:@"DELETE FROM %@ WHERE ", tableName];

  NSString *toDeleteArgument = [NSString stringWithFormat:@"%@ = ? OR ", kRmqIdColumn];

  int toDelete = (int)[rmqIds count];
  if (toDelete == 0) {
    return 0;
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
    NSRange range = NSMakeRange([whereArgument length] -4, 4);
    [whereArgument deleteCharactersInRange:range];
    NSString *deleteQuery = [NSString stringWithFormat:@"%@ %@", delete, whereArgument];


    // sqlite update
    sqlite3_stmt *delete_statement;
    if (sqlite3_prepare_v2(_database, [deleteQuery UTF8String],
                           -1, &delete_statement, NULL) != SQLITE_OK) {
      _FIRMessagingRmqLogAndExit(delete_statement, 0);
    }

    // bind values
    int rmqIndex = 0;
    int placeholderIndex = 1; // placeholders in sqlite3 start with 1
    for (NSString *rmqId in rmqIds) { // objectAtIndex: is O(n) -- would make it slow
      if (rmqIndex < start) {
        rmqIndex++;
        continue;
      } else if (rmqIndex >= end) {
        break;
      } else {
        if (isRmqIDString) {
          if (sqlite3_bind_text(delete_statement,
                                placeholderIndex,
                                [rmqId UTF8String],
                                (int)[rmqId length],
                                SQLITE_STATIC) != SQLITE_OK) {
            FIRMessagingLoggerDebug(kFIRMessagingMessageCodeRmq2PersistentStore003,
                                    @"Failed to bind rmqID %@", rmqId);
            continue;
          }
        } else {
          int64_t rmqIdValue = [rmqId longLongValue];
          sqlite3_bind_int64(delete_statement, placeholderIndex, rmqIdValue);
        }
        placeholderIndex++;
      }
      rmqIndex++;
    }
    if (sqlite3_step(delete_statement) != SQLITE_DONE) {
      _FIRMessagingRmqLogAndExit(delete_statement, deleteCount);
    }
    sqlite3_finalize(delete_statement);
    deleteCount += sqlite3_changes(_database);
    start = end;
  }

  // if we are here all of our sqlite queries should have succeeded
  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeRmq2PersistentStore004,
                          @"%@ Trying to delete %d s2D ID's, successfully deleted %d",
                          kFCMRmqStoreTag, toDelete, deleteCount);
  return deleteCount;
}

#pragma mark - Query

- (int64_t)queryHighestRmqId {
  NSString *queryFormat = @"SELECT %@ FROM %@ ORDER BY %@ DESC LIMIT %d";
  NSString *query = [NSString stringWithFormat:queryFormat,
                     kRmqIdColumn, // column
                     kTableOutgoingRmqMessages, // table
                     kRmqIdColumn, // order by column
                     1]; // limit

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
                     kRmqIdColumn, // column
                     kTableLastRmqId, // table
                     kRmqIdColumn, // order by column
                     1]; // limit

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

- (BOOL)updateLastOutgoingRmqId:(int64_t)rmqID {
  NSString *queryFormat = @"INSERT OR REPLACE INTO %@ (%@, %@) VALUES (?, ?)";
  NSString *query = [NSString stringWithFormat:queryFormat,
                     kTableLastRmqId, // table
                     kIdColumn, kRmqIdColumn]; // columns
  sqlite3_stmt *statement;
  if (sqlite3_prepare_v2(_database, [query UTF8String], -1, &statement, NULL) != SQLITE_OK) {
    _FIRMessagingRmqLogAndExit(statement, NO);
  }
  if (sqlite3_bind_int(statement, 1, 1) != SQLITE_OK) {
    _FIRMessagingRmqLogAndExit(statement, NO);
  }
  if (sqlite3_bind_int64(statement, 2, rmqID) != SQLITE_OK) {
    _FIRMessagingRmqLogAndExit(statement, NO);
  }
  if (sqlite3_step(statement) != SQLITE_DONE) {
    _FIRMessagingRmqLogAndExit(statement, NO);
  }
  sqlite3_finalize(statement);
  return YES;
}

- (NSArray *)unackedS2dRmqIds {
  NSString *queryFormat = @"SELECT %@ FROM %@ ORDER BY %@ ASC";
  NSString *query = [NSString stringWithFormat:queryFormat,
                     kRmqIdColumn,
                     kTableS2DRmqIds,
                     kRmqIdColumn];
  sqlite3_stmt *statement;
  if (sqlite3_prepare_v2(_database, [query UTF8String], -1, &statement, NULL) != SQLITE_OK) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeRmq2PersistentStore005,
                            @"%@: Could not find s2d ids", kFCMRmqStoreTag);
    _FIRMessagingRmqLogAndExit(statement, @[]);
  }
  NSMutableArray *rmqIDArray = [NSMutableArray array];
  while (sqlite3_step(statement) == SQLITE_ROW) {
    const char *rmqID = (char *)sqlite3_column_text(statement, 0);
    [rmqIDArray addObject:[NSString stringWithUTF8String:rmqID]];
  }
  sqlite3_finalize(statement);
  return rmqIDArray;
}

#pragma mark - Scan

- (void)scanOutgoingRmqMessagesWithHandler:(FCMOutgoingRmqMessagesTableHandler)handler {
  static NSString *queryFormat = @"SELECT %@ FROM %@ WHERE %@ != 0 ORDER BY %@ ASC";
  NSString *query = [NSString stringWithFormat:queryFormat,
                     kOutgoingRmqMessagesColumns, // select (rmq_id, type, data)
                     kTableOutgoingRmqMessages, // from table
                     kRmqIdColumn, // where
                     kRmqIdColumn]; // order by
  sqlite3_stmt *statement;
  if (sqlite3_prepare_v2(_database, [query UTF8String], -1, &statement, NULL) != SQLITE_OK) {
    [self logError];
    sqlite3_finalize(statement);
    return;
  }
  // can query sqlite3 for this but this is fine
  const int rmqIdColumnNumber = 0;
  const int typeColumnNumber = 1;
  const int dataColumnNumber = 2;
  while (sqlite3_step(statement) == SQLITE_ROW) {
    int64_t rmqId = sqlite3_column_int64(statement, rmqIdColumnNumber);
    int8_t type = sqlite3_column_int(statement, typeColumnNumber);
    const void *bytes = sqlite3_column_blob(statement, dataColumnNumber);
    int length = sqlite3_column_bytes(statement, dataColumnNumber);
    _FIRMessagingDevAssert(bytes != NULL,
                           @"%@ Message with no data being stored in Rmq",
                           kFCMRmqStoreTag);
    NSData *data = [NSData dataWithBytes:bytes length:length];
    handler(rmqId, type, data);
  }
  sqlite3_finalize(statement);
}

#pragma mark - Sync Messages

- (FIRMessagingPersistentSyncMessage *)querySyncMessageWithRmqID:(NSString *)rmqID {
  _FIRMessagingDevAssert([rmqID length], @"Invalid rmqID key %@ to search in SYNC_RMQ", rmqID);

  NSString *queryFormat = @"SELECT %@ FROM %@ WHERE %@ = '%@'";
  NSString *query = [NSString stringWithFormat:queryFormat,
                     kSyncMessagesColumns, // SELECT (rmq_id, expiration_ts, apns_recv, mcs_recv)
                     kTableSyncMessages,   // FROM sync_rmq
                     kRmqIdColumn,         // WHERE rmq_id
                     rmqID];

  sqlite3_stmt *stmt;
  if (sqlite3_prepare_v2(_database, [query UTF8String], -1, &stmt, NULL) != SQLITE_OK) {
    [self logError];
    sqlite3_finalize(stmt);
    return nil;
  }

  const int rmqIDColumn = 0;
  const int expirationTimestampColumn = 1;
  const int apnsReceivedColumn = 2;
  const int mcsReceivedColumn = 3;

  int count = 0;
  FIRMessagingPersistentSyncMessage *persistentMessage;

  while (sqlite3_step(stmt) == SQLITE_ROW) {
    NSString *rmqID =
        [NSString stringWithUTF8String:(char *)sqlite3_column_text(stmt, rmqIDColumn)];
    int64_t expirationTimestamp = sqlite3_column_int64(stmt, expirationTimestampColumn);
    BOOL apnsReceived = sqlite3_column_int(stmt, apnsReceivedColumn);
    BOOL mcsReceived = sqlite3_column_int(stmt, mcsReceivedColumn);

    // create a new persistent message
    persistentMessage =
        [[FIRMessagingPersistentSyncMessage alloc] initWithRMQID:rmqID expirationTime:expirationTimestamp];
    persistentMessage.apnsReceived = apnsReceived;
    persistentMessage.mcsReceived = mcsReceived;

    count++;
  }
  sqlite3_finalize(stmt);

  _FIRMessagingDevAssert(count <= 1, @"Found multiple messages in %@ with same RMQ ID", kTableSyncMessages);
  return persistentMessage;
}

- (BOOL)deleteSyncMessageWithRmqID:(NSString *)rmqID {
  _FIRMessagingDevAssert([rmqID length], @"Invalid rmqID key %@ to delete in SYNC_RMQ", rmqID);
  return [self deleteMessagesFromTable:kTableSyncMessages withRmqIds:@[rmqID]] > 0;
}

- (int)deleteExpiredOrFinishedSyncMessages:(NSError *__autoreleasing *)error {
  int64_t now = FIRMessagingCurrentTimestampInSeconds();
  NSString *deleteSQL = @"DELETE FROM %@ "
                        @"WHERE %@ < %lld OR "  // expirationTime < now
                        @"(%@ = 1 AND %@ = 1)";  // apns_received = 1 AND mcs_received = 1
  NSString *query = [NSString stringWithFormat:deleteSQL,
                     kTableSyncMessages,
                     kSyncMessageExpirationTimestampColumn,
                     now,
                     kSyncMessageAPNSReceivedColumn,
                     kSyncMessageMCSReceivedColumn];

  NSString *errorReason = @"Failed to save delete expired sync messages from store.";

  sqlite3_stmt *stmt;
  if (sqlite3_prepare_v2(_database, [query UTF8String], -1, &stmt, NULL) != SQLITE_OK) {
    if (error) {
      *error = [NSError fcm_errorWithCode:sqlite3_errcode(_database)
                                 userInfo:@{ @"error" : errorReason }];
    }
    _FIRMessagingRmqLogAndExit(stmt, 0);
  }

  if (sqlite3_step(stmt) != SQLITE_DONE) {
    if (error) {
      *error = [NSError fcm_errorWithCode:sqlite3_errcode(_database)
                                 userInfo:@{ @"error" : errorReason }];
    }
    _FIRMessagingRmqLogAndExit(stmt, 0);
  }

  sqlite3_finalize(stmt);
  int deleteCount = sqlite3_changes(_database);
  return deleteCount;
}

- (BOOL)saveSyncMessageWithRmqID:(NSString *)rmqID
                  expirationTime:(int64_t)expirationTime
                    apnsReceived:(BOOL)apnsReceived
                     mcsReceived:(BOOL)mcsReceived
                           error:(NSError **)error {
  _FIRMessagingDevAssert([rmqID length], @"Invalid nil message to persist to SYNC_RMQ");

  NSString *insertFormat = @"INSERT INTO %@ (%@, %@, %@, %@) VALUES (?, ?, ?, ?)";
  NSString *insertSQL = [NSString stringWithFormat:insertFormat,
                         kTableSyncMessages, // Table name
                         kRmqIdColumn, // rmq_id
                         kSyncMessageExpirationTimestampColumn, // expiration_ts
                         kSyncMessageAPNSReceivedColumn, // apns_recv
                         kSyncMessageMCSReceivedColumn /* mcs_recv */];

  sqlite3_stmt *stmt;

  if (sqlite3_prepare_v2(_database, [insertSQL UTF8String], -1, &stmt, NULL) != SQLITE_OK) {
    if (error) {
      *error = [NSError fcm_errorWithCode:sqlite3_errcode(_database)
                                 userInfo:@{ @"error" : @"Failed to save sync message to store." }];
    }
    _FIRMessagingRmqLogAndExit(stmt, NO);
  }

  if (sqlite3_bind_text(stmt, 1, [rmqID UTF8String], (int)[rmqID length], NULL) != SQLITE_OK) {
    _FIRMessagingRmqLogAndExit(stmt, NO);
  }

  if (sqlite3_bind_int64(stmt, 2, expirationTime) != SQLITE_OK) {
    _FIRMessagingRmqLogAndExit(stmt, NO);
  }

  if (sqlite3_bind_int(stmt, 3, apnsReceived ? 1 : 0) != SQLITE_OK) {
    _FIRMessagingRmqLogAndExit(stmt, NO);
  }

  if (sqlite3_bind_int(stmt, 4, mcsReceived ? 1 : 0) != SQLITE_OK) {
    _FIRMessagingRmqLogAndExit(stmt, NO);
  }

  if (sqlite3_step(stmt) != SQLITE_DONE) {
    _FIRMessagingRmqLogAndExit(stmt, NO);
  }

  sqlite3_finalize(stmt);
  return YES;
}

- (BOOL)updateSyncMessageViaAPNSWithRmqID:(NSString *)rmqID
                                    error:(NSError **)error {
  return [self updateSyncMessageWithRmqID:rmqID
                                   column:kSyncMessageAPNSReceivedColumn
                                    value:YES
                                    error:error];
}

- (BOOL)updateSyncMessageViaMCSWithRmqID:(NSString *)rmqID
                                   error:(NSError *__autoreleasing *)error {
  return [self updateSyncMessageWithRmqID:rmqID
                                   column:kSyncMessageMCSReceivedColumn
                                    value:YES
                                    error:error];
}

- (BOOL)updateSyncMessageWithRmqID:(NSString *)rmqID
                            column:(NSString *)column
                             value:(BOOL)value
                             error:(NSError **)error {
  _FIRMessagingDevAssert([column isEqualToString:kSyncMessageAPNSReceivedColumn] ||
                [column isEqualToString:kSyncMessageMCSReceivedColumn],
                @"Invalid column name %@ for SYNC_RMQ", column);
  NSString *queryFormat = @"UPDATE %@ "  // Table name
                          @"SET %@ = %d "  // column=value
                          @"WHERE %@ = ?";  // condition
  NSString *query = [NSString stringWithFormat:queryFormat,
                     kTableSyncMessages,
                     column,
                     value ? 1 : 0,
                     kRmqIdColumn];
  sqlite3_stmt *stmt;

  if (sqlite3_prepare_v2(_database, [query UTF8String], -1, &stmt, NULL) != SQLITE_OK) {
    if (error) {
      *error = [NSError fcm_errorWithCode:sqlite3_errcode(_database)
                                 userInfo:@{ @"error" : @"Failed to update sync message"}];
    }
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

#pragma mark - Private

- (NSString *)lastErrorMessage {
  return [NSString stringWithFormat:@"%s", sqlite3_errmsg(_database)];
}

- (int)lastErrorCode {
  return sqlite3_errcode(_database);
}

- (void)logError {
  FIRMessagingLoggerError(kFIRMessagingMessageCodeRmq2PersistentStore006,
                          @"%@ error: code (%d) message: %@", kFCMRmqStoreTag, [self lastErrorCode],
                          [self lastErrorMessage]);
}

- (void)logErrorAndFinalizeStatement:(sqlite3_stmt *)stmt {
  [self logError];
  sqlite3_finalize(stmt);
}

@end
