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

#import <sqlite3.h>

#import "FirebaseRemoteConfig/Sources/RCNConfigDBManager.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigDefines.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigValue_Internal.h"

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRLogger.h>

/// Using macro for securely preprocessing string concatenation in query before runtime.
#define RCNTableNameMain "main"
#define RCNTableNameMainActive "main_active"
#define RCNTableNameMainDefault "main_default"
#define RCNTableNameMetadata "fetch_metadata"
#define RCNTableNameInternalMetadata "internal_metadata"
#define RCNTableNameExperiment "experiment"

/// SQLite file name in versions 0, 1 and 2.
static NSString *const RCNDatabaseName = @"RemoteConfig.sqlite3";
/// The application support sub-directory that the Remote Config database resides in.
static NSString *const RCNRemoteConfigApplicationSupportSubDirectory = @"Google/RemoteConfig";

/// Remote Config database path for deprecated V0 version.
static NSString *RemoteConfigPathForOldDatabaseV0() {
  NSArray *dirPaths =
      NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *docPath = dirPaths.firstObject;
  return [docPath stringByAppendingPathComponent:RCNDatabaseName];
}

/// Remote Config database path for current database.
static NSString *RemoteConfigPathForDatabase(void) {
  NSArray *dirPaths =
      NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
  NSString *appSupportPath = dirPaths.firstObject;
  NSArray *components =
      @[ appSupportPath, RCNRemoteConfigApplicationSupportSubDirectory, RCNDatabaseName ];
  return [NSString pathWithComponents:components];
}

static BOOL RemoteConfigAddSkipBackupAttributeToItemAtPath(NSString *filePathString) {
  NSURL *URL = [NSURL fileURLWithPath:filePathString];
  assert([[NSFileManager defaultManager] fileExistsAtPath:[URL path]]);

  NSError *error = nil;
  BOOL success = [URL setResourceValue:[NSNumber numberWithBool:YES]
                                forKey:NSURLIsExcludedFromBackupKey
                                 error:&error];
  if (!success) {
    FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000017", @"Error excluding %@ from backup %@.",
                [URL lastPathComponent], error);
  }
  return success;
}

static BOOL RemoteConfigCreateFilePathIfNotExist(NSString *filePath) {
  if (!filePath || !filePath.length) {
    FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000018",
                @"Failed to create subdirectory for an empty file path.");
    return NO;
  }
  NSFileManager *fileManager = [NSFileManager defaultManager];
  if (![fileManager fileExistsAtPath:filePath]) {
    NSError *error;
    [fileManager createDirectoryAtPath:[filePath stringByDeletingLastPathComponent]
           withIntermediateDirectories:YES
                            attributes:nil
                                 error:&error];
    if (error) {
      FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000019",
                  @"Failed to create subdirectory for database file: %@.", error);
      return NO;
    }
  }
  return YES;
}

static NSArray *RemoteConfigMetadataTableColumnsInOrder() {
  return @[
    RCNKeyBundleIdentifier, RCNKeyFetchTime, RCNKeyDigestPerNamespace, RCNKeyDeviceContext,
    RCNKeyAppContext, RCNKeySuccessFetchTime, RCNKeyFailureFetchTime, RCNKeyLastFetchStatus,
    RCNKeyLastFetchError, RCNKeyLastApplyTime, RCNKeyLastSetDefaultsTime
  ];
}

@interface RCNConfigDBManager () {
  /// Database storing all the config information.
  sqlite3 *_database;
  /// Serial queue for database read/write operations.
  dispatch_queue_t _databaseOperationQueue;
}
@end

@implementation RCNConfigDBManager

+ (instancetype)sharedInstance {
  static dispatch_once_t onceToken;
  static RCNConfigDBManager *sharedInstance;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[RCNConfigDBManager alloc] init];
  });
  return sharedInstance;
}

/// Returns the current version of the Remote Config database.
+ (NSString *)remoteConfigPathForDatabase {
  return RemoteConfigPathForDatabase();
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _databaseOperationQueue =
        dispatch_queue_create("com.google.GoogleConfigService.database", DISPATCH_QUEUE_SERIAL);
    [self createOrOpenDatabase];
  }
  return self;
}

#pragma mark - database
- (void)migrateV1NamespaceToV2Namespace {
  for (int table = 0; table < 3; table++) {
    NSString *tableName = @"" RCNTableNameMain;
    switch (table) {
      case 1:
        tableName = @"" RCNTableNameMainActive;
        break;
      case 2:
        tableName = @"" RCNTableNameMainDefault;
        break;
      default:
        break;
    }
    NSString *SQLString = [NSString
        stringWithFormat:@"SELECT namespace FROM %@ WHERE namespace NOT LIKE '%%:%%'", tableName];
    const char *SQL = [SQLString UTF8String];
    sqlite3_stmt *statement = [self prepareSQL:SQL];
    if (!statement) {
      return;
    }
    NSMutableArray<NSString *> *namespaceArray = [[NSMutableArray alloc] init];
    while (sqlite3_step(statement) == SQLITE_ROW) {
      NSString *configNamespace =
          [[NSString alloc] initWithUTF8String:(char *)sqlite3_column_text(statement, 0)];
      [namespaceArray addObject:configNamespace];
    }
    sqlite3_finalize(statement);

    // Update.
    for (NSString *namespaceToUpdate in namespaceArray) {
      NSString *newNamespace =
          [NSString stringWithFormat:@"%@:%@", namespaceToUpdate, kFIRDefaultAppName];
      NSString *updateSQLString =
          [NSString stringWithFormat:@"UPDATE %@ SET namespace = ? WHERE namespace = ?", tableName];
      const char *updateSQL = [updateSQLString UTF8String];
      sqlite3_stmt *updateStatement = [self prepareSQL:updateSQL];
      if (!updateStatement) {
        return;
      }
      NSArray<NSString *> *updateParams = @[ newNamespace, namespaceToUpdate ];
      [self bindStringsToStatement:updateStatement stringArray:updateParams];

      int result = sqlite3_step(updateStatement);
      if (result != SQLITE_DONE) {
        [self logErrorWithSQL:SQL finalizeStatement:updateStatement returnValue:NO];
        return;
      }
      sqlite3_finalize(updateStatement);
    }
  }
}

- (void)createOrOpenDatabase {
  __weak RCNConfigDBManager *weakSelf = self;
  dispatch_async(_databaseOperationQueue, ^{
    RCNConfigDBManager *strongSelf = weakSelf;
    if (!strongSelf) {
      return;
    }
    NSString *oldV0DBPath = RemoteConfigPathForOldDatabaseV0();
    // Backward Compatibility
    if ([[NSFileManager defaultManager] fileExistsAtPath:oldV0DBPath]) {
      FIRLogInfo(kFIRLoggerRemoteConfig, @"I-RCN000009",
                 @"Old database V0 exists, removed it and replace with the new one.");
      [strongSelf removeDatabase:oldV0DBPath];
    }
    NSString *dbPath = [RCNConfigDBManager remoteConfigPathForDatabase];
    FIRLogInfo(kFIRLoggerRemoteConfig, @"I-RCN000062", @"Loading database at path %@", dbPath);
    const char *databasePath = dbPath.UTF8String;
    // Create or open database path.
    if (!RemoteConfigCreateFilePathIfNotExist(dbPath)) {
      return;
    }
    int flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FILEPROTECTION_COMPLETE |
                SQLITE_OPEN_FULLMUTEX;
    if (sqlite3_open_v2(databasePath, &strongSelf->_database, flags, NULL) == SQLITE_OK) {
      // Always try to create table if not exists for backward compatibility.
      if (![strongSelf createTableSchema]) {
        // Remove database before fail.
        [strongSelf removeDatabase:dbPath];
        FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000010", @"Failed to create table.");
        // Create a new database if existing database file is corrupted.
        if (!RemoteConfigCreateFilePathIfNotExist(dbPath)) {
          return;
        }
        if (sqlite3_open_v2(databasePath, &strongSelf->_database, flags, NULL) == SQLITE_OK) {
          if (![strongSelf createTableSchema]) {
            // Remove database before fail.
            [strongSelf removeDatabase:dbPath];
            // If it failed again, there's nothing we can do here.
            FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000010", @"Failed to create table.");
          } else {
            // Exclude the app data used from iCloud backup.
            RemoteConfigAddSkipBackupAttributeToItemAtPath(dbPath);
          }
        } else {
          [strongSelf logDatabaseError];
        }
      } else {
        // DB file already exists. Migrate any V1 namespace column entries to V2 fully qualified
        // 'namespace:FIRApp' entries.
        [self migrateV1NamespaceToV2Namespace];
        // Exclude the app data used from iCloud backup.
        RemoteConfigAddSkipBackupAttributeToItemAtPath(dbPath);
      }
    } else {
      [strongSelf logDatabaseError];
    }
  });
}

- (BOOL)createTableSchema {
  RCN_MUST_NOT_BE_MAIN_THREAD();
  static const char *createTableMain =
      "create TABLE IF NOT EXISTS " RCNTableNameMain
      " (_id INTEGER PRIMARY KEY, bundle_identifier TEXT, namespace TEXT, key TEXT, value BLOB)";

  static const char *createTableMainActive =
      "create TABLE IF NOT EXISTS " RCNTableNameMainActive
      " (_id INTEGER PRIMARY KEY, bundle_identifier TEXT, namespace TEXT, key TEXT, value BLOB)";

  static const char *createTableMainDefault =
      "create TABLE IF NOT EXISTS " RCNTableNameMainDefault
      " (_id INTEGER PRIMARY KEY, bundle_identifier TEXT, namespace TEXT, key TEXT, value BLOB)";

  static const char *createTableMetadata =
      "create TABLE IF NOT EXISTS " RCNTableNameMetadata
      " (_id INTEGER PRIMARY KEY, bundle_identifier"
      " TEXT, fetch_time INTEGER, digest_per_ns BLOB, device_context BLOB, app_context BLOB, "
      "success_fetch_time BLOB, failure_fetch_time BLOB, last_fetch_status INTEGER, "
      "last_fetch_error INTEGER, last_apply_time INTEGER, last_set_defaults_time INTEGER)";

  static const char *createTableInternalMetadata =
      "create TABLE IF NOT EXISTS " RCNTableNameInternalMetadata
      " (_id INTEGER PRIMARY KEY, key TEXT, value BLOB)";

  static const char *createTableExperiment = "create TABLE IF NOT EXISTS " RCNTableNameExperiment
                                             " (_id INTEGER PRIMARY KEY, key TEXT, value BLOB)";

  return [self executeQuery:createTableMain] && [self executeQuery:createTableMainActive] &&
         [self executeQuery:createTableMainDefault] && [self executeQuery:createTableMetadata] &&
         [self executeQuery:createTableInternalMetadata] &&
         [self executeQuery:createTableExperiment];
}

- (void)removeDatabaseOnDatabaseQueueAtPath:(NSString *)path {
  __weak RCNConfigDBManager *weakSelf = self;
  dispatch_sync(_databaseOperationQueue, ^{
    RCNConfigDBManager *strongSelf = weakSelf;
    if (!strongSelf) {
      return;
    }
    if (sqlite3_close(strongSelf->_database) != SQLITE_OK) {
      [self logDatabaseError];
    }
    strongSelf->_database = nil;

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    if (![fileManager removeItemAtPath:path error:&error]) {
      FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000011",
                  @"Failed to remove database at path %@ for error %@.", path, error);
    }
  });
}

- (void)removeDatabase:(NSString *)path {
  if (sqlite3_close(_database) != SQLITE_OK) {
    [self logDatabaseError];
  }
  _database = nil;

  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSError *error;
  if (![fileManager removeItemAtPath:path error:&error]) {
    FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000011",
                @"Failed to remove database at path %@ for error %@.", path, error);
  }
}

#pragma mark - execute
- (BOOL)executeQuery:(const char *)SQL {
  RCN_MUST_NOT_BE_MAIN_THREAD();
  char *error;
  if (sqlite3_exec(_database, SQL, nil, nil, &error) != SQLITE_OK) {
    FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000012", @"Failed to execute query with error %s.",
                error);
    return NO;
  }
  return YES;
}

#pragma mark - insert
- (void)insertMetadataTableWithValues:(NSDictionary *)columnNameToValue
                    completionHandler:(RCNDBCompletion)handler {
  __weak RCNConfigDBManager *weakSelf = self;
  dispatch_async(_databaseOperationQueue, ^{
    BOOL success = [weakSelf insertMetadataTableWithValues:columnNameToValue];
    if (handler) {
      dispatch_async(dispatch_get_main_queue(), ^{
        handler(success, nil);
      });
    }
  });
}

- (BOOL)insertMetadataTableWithValues:(NSDictionary *)columnNameToValue {
  RCN_MUST_NOT_BE_MAIN_THREAD();
  static const char *SQL =
      "INSERT INTO " RCNTableNameMetadata
      " (bundle_identifier, fetch_time, digest_per_ns, device_context, "
      "app_context, success_fetch_time, failure_fetch_time, last_fetch_status, "
      "last_fetch_error, last_apply_time, last_set_defaults_time) values (?, ?, ?, ?, ?, "
      "?, ?, ?, ?, ?, ?)";

  sqlite3_stmt *statement = [self prepareSQL:SQL];
  if (!statement) {
    [self logErrorWithSQL:SQL finalizeStatement:nil returnValue:NO];
    return NO;
  }

  NSArray *columns = RemoteConfigMetadataTableColumnsInOrder();
  int index = 0;
  for (NSString *columnName in columns) {
    if ([columnName isEqualToString:RCNKeyBundleIdentifier]) {
      NSString *value = columnNameToValue[columnName];
      if (![self bindStringToStatement:statement index:++index string:value]) {
        return [self logErrorWithSQL:SQL finalizeStatement:statement returnValue:NO];
      }
    } else if ([columnName isEqualToString:RCNKeyFetchTime] ||
               [columnName isEqualToString:RCNKeyLastApplyTime] ||
               [columnName isEqualToString:RCNKeyLastSetDefaultsTime]) {
      double value = [columnNameToValue[columnName] doubleValue];
      if (sqlite3_bind_double(statement, ++index, value) != SQLITE_OK) {
        return [self logErrorWithSQL:SQL finalizeStatement:statement returnValue:NO];
      }
    } else if ([columnName isEqualToString:RCNKeyLastFetchStatus] ||
               [columnName isEqualToString:RCNKeyLastFetchError]) {
      int value = [columnNameToValue[columnName] intValue];
      if (sqlite3_bind_int(statement, ++index, value) != SQLITE_OK) {
        return [self logErrorWithSQL:SQL finalizeStatement:statement returnValue:NO];
      }
    } else {
      NSData *data = columnNameToValue[columnName];
      if (sqlite3_bind_blob(statement, ++index, data.bytes, (int)data.length, NULL) != SQLITE_OK) {
        return [self logErrorWithSQL:SQL finalizeStatement:statement returnValue:NO];
      }
    }
  }
  if (sqlite3_step(statement) != SQLITE_DONE) {
    return [self logErrorWithSQL:SQL finalizeStatement:statement returnValue:NO];
  }
  sqlite3_finalize(statement);
  return YES;
}

- (void)insertMainTableWithValues:(NSArray *)values
                       fromSource:(RCNDBSource)source
                completionHandler:(RCNDBCompletion)handler {
  __weak RCNConfigDBManager *weakSelf = self;
  dispatch_async(_databaseOperationQueue, ^{
    BOOL success = [weakSelf insertMainTableWithValues:values fromSource:source];
    if (handler) {
      dispatch_async(dispatch_get_main_queue(), ^{
        handler(success, nil);
      });
    }
  });
}

- (BOOL)insertMainTableWithValues:(NSArray *)values fromSource:(RCNDBSource)source {
  RCN_MUST_NOT_BE_MAIN_THREAD();
  if (values.count != 4) {
    FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000013",
                @"Failed to insert config record. Wrong number of give parameters, current "
                @"number is %ld, correct number is 4.",
                (long)values.count);
    return NO;
  }
  const char *SQL = "INSERT INTO " RCNTableNameMain
                    " (bundle_identifier, namespace, key, value) values (?, ?, ?, ?)";
  if (source == RCNDBSourceDefault) {
    SQL = "INSERT INTO " RCNTableNameMainDefault
          " (bundle_identifier, namespace, key, value) values (?, ?, ?, ?)";
  } else if (source == RCNDBSourceActive) {
    SQL = "INSERT INTO " RCNTableNameMainActive
          " (bundle_identifier, namespace, key, value) values (?, ?, ?, ?)";
  }

  sqlite3_stmt *statement = [self prepareSQL:SQL];
  if (!statement) {
    return NO;
  }

  NSString *aString = values[0];
  if (![self bindStringToStatement:statement index:1 string:aString]) {
    return [self logErrorWithSQL:SQL finalizeStatement:statement returnValue:NO];
  }
  aString = values[1];
  if (![self bindStringToStatement:statement index:2 string:aString]) {
    return [self logErrorWithSQL:SQL finalizeStatement:statement returnValue:NO];
  }
  aString = values[2];
  if (![self bindStringToStatement:statement index:3 string:aString]) {
    return [self logErrorWithSQL:SQL finalizeStatement:statement returnValue:NO];
  }
  NSData *blobData = values[3];
  if (sqlite3_bind_blob(statement, 4, blobData.bytes, (int)blobData.length, NULL) != SQLITE_OK) {
    return [self logErrorWithSQL:SQL finalizeStatement:statement returnValue:NO];
  }
  if (sqlite3_step(statement) != SQLITE_DONE) {
    return [self logErrorWithSQL:SQL finalizeStatement:statement returnValue:NO];
  }
  sqlite3_finalize(statement);
  return YES;
}

- (void)insertInternalMetadataTableWithValues:(NSArray *)values
                            completionHandler:(RCNDBCompletion)handler {
  __weak RCNConfigDBManager *weakSelf = self;
  dispatch_async(_databaseOperationQueue, ^{
    BOOL success = [weakSelf insertInternalMetadataWithValues:values];
    if (handler) {
      dispatch_async(dispatch_get_main_queue(), ^{
        handler(success, nil);
      });
    }
  });
}

- (BOOL)insertInternalMetadataWithValues:(NSArray *)values {
  RCN_MUST_NOT_BE_MAIN_THREAD();
  if (values.count != 2) {
    return NO;
  }
  const char *SQL =
      "INSERT OR REPLACE INTO " RCNTableNameInternalMetadata " (key, value) values (?, ?)";
  sqlite3_stmt *statement = [self prepareSQL:SQL];
  if (!statement) {
    return NO;
  }
  NSString *aString = values[0];
  if (![self bindStringToStatement:statement index:1 string:aString]) {
    [self logErrorWithSQL:SQL finalizeStatement:statement returnValue:NO];
    return NO;
  }
  NSData *blobData = values[1];
  if (sqlite3_bind_blob(statement, 2, blobData.bytes, (int)blobData.length, NULL) != SQLITE_OK) {
    [self logErrorWithSQL:SQL finalizeStatement:statement returnValue:NO];
    return NO;
  }
  if (sqlite3_step(statement) != SQLITE_DONE) {
    [self logErrorWithSQL:SQL finalizeStatement:statement returnValue:NO];
    return NO;
  }
  sqlite3_finalize(statement);
  return YES;
}

- (void)insertExperimentTableWithKey:(NSString *)key
                               value:(NSData *)serializedValue
                   completionHandler:(RCNDBCompletion)handler {
  dispatch_async(_databaseOperationQueue, ^{
    BOOL success = [self insertExperimentTableWithKey:key value:serializedValue];
    if (handler) {
      dispatch_async(dispatch_get_main_queue(), ^{
        handler(success, nil);
      });
    }
  });
}

- (BOOL)insertExperimentTableWithKey:(NSString *)key value:(NSData *)dataValue {
  if ([key isEqualToString:@RCNExperimentTableKeyMetadata]) {
    return [self updateExperimentMetadata:dataValue];
  }

  RCN_MUST_NOT_BE_MAIN_THREAD();
  const char *SQL = "INSERT INTO " RCNTableNameExperiment " (key, value) values (?, ?)";

  sqlite3_stmt *statement = [self prepareSQL:SQL];
  if (!statement) {
    return NO;
  }

  if (![self bindStringToStatement:statement index:1 string:key]) {
    return [self logErrorWithSQL:SQL finalizeStatement:statement returnValue:NO];
  }

  if (sqlite3_bind_blob(statement, 2, dataValue.bytes, (int)dataValue.length, NULL) != SQLITE_OK) {
    return [self logErrorWithSQL:SQL finalizeStatement:statement returnValue:NO];
  }

  if (sqlite3_step(statement) != SQLITE_DONE) {
    return [self logErrorWithSQL:SQL finalizeStatement:statement returnValue:NO];
  }
  sqlite3_finalize(statement);
  return YES;
}

- (BOOL)updateExperimentMetadata:(NSData *)dataValue {
  RCN_MUST_NOT_BE_MAIN_THREAD();
  const char *SQL = "INSERT OR REPLACE INTO " RCNTableNameExperiment
                    " (_id, key, value) values ((SELECT _id from " RCNTableNameExperiment
                    " WHERE key = ?), ?, ?)";

  sqlite3_stmt *statement = [self prepareSQL:SQL];
  if (!statement) {
    return NO;
  }

  if (![self bindStringToStatement:statement index:1 string:@RCNExperimentTableKeyMetadata]) {
    return [self logErrorWithSQL:SQL finalizeStatement:statement returnValue:NO];
  }

  if (![self bindStringToStatement:statement index:2 string:@RCNExperimentTableKeyMetadata]) {
    return [self logErrorWithSQL:SQL finalizeStatement:statement returnValue:NO];
  }
  if (sqlite3_bind_blob(statement, 3, dataValue.bytes, (int)dataValue.length, NULL) != SQLITE_OK) {
    return [self logErrorWithSQL:SQL finalizeStatement:statement returnValue:NO];
  }

  if (sqlite3_step(statement) != SQLITE_DONE) {
    return [self logErrorWithSQL:SQL finalizeStatement:statement returnValue:NO];
  }
  sqlite3_finalize(statement);
  return YES;
}

#pragma mark - update

- (void)updateMetadataWithOption:(RCNUpdateOption)option
                          values:(NSArray *)values
               completionHandler:(RCNDBCompletion)handler {
  dispatch_async(_databaseOperationQueue, ^{
    BOOL success = [self updateMetadataTableWithOption:option andValues:values];
    if (handler) {
      dispatch_async(dispatch_get_main_queue(), ^{
        handler(success, nil);
      });
    }
  });
}

- (BOOL)updateMetadataTableWithOption:(RCNUpdateOption)option andValues:(NSArray *)values {
  RCN_MUST_NOT_BE_MAIN_THREAD();
  static const char *SQL =
      "UPDATE " RCNTableNameMetadata " (last_fetch_status, last_fetch_error, last_apply_time, "
      "last_set_defaults_time) values (?, ?, ?, ?)";
  if (option == RCNUpdateOptionFetchStatus) {
    SQL = "UPDATE " RCNTableNameMetadata " SET last_fetch_status = ?, last_fetch_error = ?";
  } else if (option == RCNUpdateOptionApplyTime) {
    SQL = "UPDATE " RCNTableNameMetadata " SET last_apply_time = ?";
  } else if (option == RCNUpdateOptionDefaultTime) {
    SQL = "UPDATE " RCNTableNameMetadata " SET last_set_defaults_time = ?";
  } else {
    return NO;
  }
  sqlite3_stmt *statement = [self prepareSQL:SQL];
  if (!statement) {
    return NO;
  }

  int index = 0;
  if ((option == RCNUpdateOptionApplyTime || option == RCNUpdateOptionDefaultTime) &&
      values.count == 1) {
    double value = [values[0] doubleValue];
    if (sqlite3_bind_double(statement, ++index, value) != SQLITE_OK) {
      return [self logErrorWithSQL:SQL finalizeStatement:statement returnValue:NO];
    }
  } else if (option == RCNUpdateOptionFetchStatus && values.count == 2) {
    int value = [values[0] intValue];
    if (sqlite3_bind_int(statement, ++index, value) != SQLITE_OK) {
      return [self logErrorWithSQL:SQL finalizeStatement:statement returnValue:NO];
    }
    value = [values[1] intValue];
    if (sqlite3_bind_int(statement, ++index, value) != SQLITE_OK) {
      return [self logErrorWithSQL:SQL finalizeStatement:statement returnValue:NO];
    }
  }
  if (sqlite3_step(statement) != SQLITE_DONE) {
    return [self logErrorWithSQL:SQL finalizeStatement:statement returnValue:NO];
  }
  sqlite3_finalize(statement);
  return YES;
}
#pragma mark - read from DB

- (NSDictionary *)loadMetadataWithBundleIdentifier:(NSString *)bundleIdentifier {
  __block NSDictionary *metadataTableResult;
  __weak RCNConfigDBManager *weakSelf = self;
  dispatch_sync(_databaseOperationQueue, ^{
    metadataTableResult = [weakSelf loadMetadataTableWithBundleIdentifier:bundleIdentifier];
  });
  if (metadataTableResult) {
    return metadataTableResult;
  }
  return [[NSDictionary alloc] init];
}

- (NSMutableDictionary *)loadMetadataTableWithBundleIdentifier:(NSString *)bundleIdentifier {
  NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
  const char *SQL =
      "SELECT bundle_identifier, fetch_time, digest_per_ns, device_context, app_context, "
      "success_fetch_time, failure_fetch_time , last_fetch_status, "
      "last_fetch_error, last_apply_time, last_set_defaults_time FROM " RCNTableNameMetadata
      " WHERE bundle_identifier = ?";
  sqlite3_stmt *statement = [self prepareSQL:SQL];
  if (!statement) {
    return nil;
  }

  NSArray *params = @[ bundleIdentifier ];
  [self bindStringsToStatement:statement stringArray:params];

  while (sqlite3_step(statement) == SQLITE_ROW) {
    NSString *dbBundleIdentifier =
        [[NSString alloc] initWithUTF8String:(char *)sqlite3_column_text(statement, 0)];

    if (dbBundleIdentifier && ![dbBundleIdentifier isEqualToString:bundleIdentifier]) {
      FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000014",
                  @"Load Metadata from table error: Wrong package name %@, should be %@.",
                  dbBundleIdentifier, bundleIdentifier);
      return nil;
    }

    double fetchTime = sqlite3_column_double(statement, 1);
    NSData *digestPerNamespace = [NSData dataWithBytes:(char *)sqlite3_column_blob(statement, 2)
                                                length:sqlite3_column_bytes(statement, 2)];
    NSData *deviceContext = [NSData dataWithBytes:(char *)sqlite3_column_blob(statement, 3)
                                           length:sqlite3_column_bytes(statement, 3)];
    NSData *appContext = [NSData dataWithBytes:(char *)sqlite3_column_blob(statement, 4)
                                        length:sqlite3_column_bytes(statement, 4)];
    NSData *successTimeDigest = [NSData dataWithBytes:(char *)sqlite3_column_blob(statement, 5)
                                               length:sqlite3_column_bytes(statement, 5)];
    NSData *failureTimeDigest = [NSData dataWithBytes:(char *)sqlite3_column_blob(statement, 6)
                                               length:sqlite3_column_bytes(statement, 6)];

    int lastFetchStatus = sqlite3_column_int(statement, 7);
    int lastFetchFailReason = sqlite3_column_int(statement, 8);
    double lastApplyTimestamp = sqlite3_column_double(statement, 9);
    double lastSetDefaultsTimestamp = sqlite3_column_double(statement, 10);

    NSError *error;
    NSMutableDictionary *deviceContextDict = nil;
    if (deviceContext) {
      deviceContextDict = [NSJSONSerialization JSONObjectWithData:deviceContext
                                                          options:NSJSONReadingMutableContainers
                                                            error:&error];
    }

    NSMutableDictionary *appContextDict = nil;
    if (appContext) {
      appContextDict = [NSJSONSerialization JSONObjectWithData:appContext
                                                       options:NSJSONReadingMutableContainers
                                                         error:&error];
    }

    NSMutableDictionary<NSString *, id> *digestPerNamespaceDictionary = nil;
    if (digestPerNamespace) {
      digestPerNamespaceDictionary =
          [NSJSONSerialization JSONObjectWithData:digestPerNamespace
                                          options:NSJSONReadingMutableContainers
                                            error:&error];
    }

    NSMutableArray *successTimes = nil;
    if (successTimeDigest) {
      successTimes = [NSJSONSerialization JSONObjectWithData:successTimeDigest
                                                     options:NSJSONReadingMutableContainers
                                                       error:&error];
    }

    NSMutableArray *failureTimes = nil;
    if (failureTimeDigest) {
      failureTimes = [NSJSONSerialization JSONObjectWithData:failureTimeDigest
                                                     options:NSJSONReadingMutableContainers
                                                       error:&error];
    }

    dict[RCNKeyBundleIdentifier] = bundleIdentifier;
    dict[RCNKeyFetchTime] = @(fetchTime);
    dict[RCNKeyDigestPerNamespace] = digestPerNamespaceDictionary;
    dict[RCNKeyDeviceContext] = deviceContextDict;
    dict[RCNKeyAppContext] = appContextDict;
    dict[RCNKeySuccessFetchTime] = successTimes;
    dict[RCNKeyFailureFetchTime] = failureTimes;
    dict[RCNKeyLastFetchStatus] = @(lastFetchStatus);
    dict[RCNKeyLastFetchError] = @(lastFetchFailReason);
    dict[RCNKeyLastApplyTime] = @(lastApplyTimestamp);
    dict[RCNKeyLastSetDefaultsTime] = @(lastSetDefaultsTimestamp);

    break;
  }
  sqlite3_finalize(statement);
  return dict;
}

- (void)loadExperimentWithCompletionHandler:(RCNDBCompletion)handler {
  __weak RCNConfigDBManager *weakSelf = self;
  dispatch_async(_databaseOperationQueue, ^{
    RCNConfigDBManager *strongSelf = weakSelf;
    if (!strongSelf) {
      return;
    }
    NSMutableArray *experimentPayloads =
        [strongSelf loadExperimentTableFromKey:@RCNExperimentTableKeyPayload];
    if (!experimentPayloads) {
      experimentPayloads = [[NSMutableArray alloc] init];
    }

    NSMutableDictionary *experimentMetadata;
    NSMutableArray *experiments =
        [strongSelf loadExperimentTableFromKey:@RCNExperimentTableKeyMetadata];
    // There should be only one entry for experiment metadata.
    if (experiments.count > 0) {
      NSError *error;
      experimentMetadata = [NSJSONSerialization JSONObjectWithData:experiments[0]
                                                           options:NSJSONReadingMutableContainers
                                                             error:&error];
    }
    if (!experimentMetadata) {
      experimentMetadata = [[NSMutableDictionary alloc] init];
    }

    if (handler) {
      dispatch_async(dispatch_get_main_queue(), ^{
        handler(
            YES, @{
              @RCNExperimentTableKeyPayload : [experimentPayloads copy],
              @RCNExperimentTableKeyMetadata : [experimentMetadata copy]
            });
      });
    }
  });
}

- (NSMutableArray<NSData *> *)loadExperimentTableFromKey:(NSString *)key {
  RCN_MUST_NOT_BE_MAIN_THREAD();

  NSMutableArray *results = [[NSMutableArray alloc] init];
  const char *SQL = "SELECT value FROM " RCNTableNameExperiment " WHERE key = ?";
  sqlite3_stmt *statement = [self prepareSQL:SQL];
  if (!statement) {
    return nil;
  }

  NSArray *params = @[ key ];
  [self bindStringsToStatement:statement stringArray:params];
  NSData *experimentData;
  while (sqlite3_step(statement) == SQLITE_ROW) {
    experimentData = [NSData dataWithBytes:(char *)sqlite3_column_blob(statement, 0)
                                    length:sqlite3_column_bytes(statement, 0)];
    if (experimentData) {
      [results addObject:experimentData];
    }
  }

  sqlite3_finalize(statement);
  return results;
}

- (NSDictionary *)loadInternalMetadataTable {
  __block NSMutableDictionary *internalMetadataTableResult;
  __weak RCNConfigDBManager *weakSelf = self;
  dispatch_sync(_databaseOperationQueue, ^{
    internalMetadataTableResult = [weakSelf loadInternalMetadataTableInternal];
  });
  return internalMetadataTableResult;
}

- (NSMutableDictionary *)loadInternalMetadataTableInternal {
  NSMutableDictionary *internalMetadata = [[NSMutableDictionary alloc] init];
  const char *SQL = "SELECT key, value FROM " RCNTableNameInternalMetadata;
  sqlite3_stmt *statement = [self prepareSQL:SQL];
  if (!statement) {
    return nil;
  }

  while (sqlite3_step(statement) == SQLITE_ROW) {
    NSString *key = [[NSString alloc] initWithUTF8String:(char *)sqlite3_column_text(statement, 0)];

    NSData *dataValue = [NSData dataWithBytes:(char *)sqlite3_column_blob(statement, 1)
                                       length:sqlite3_column_bytes(statement, 1)];
    internalMetadata[key] = dataValue;
  }
  sqlite3_finalize(statement);
  return internalMetadata;
}

/// This method is only meant to be called at init time. The underlying logic will need to be
/// revaluated if the assumption changes at a later time.
- (void)loadMainWithBundleIdentifier:(NSString *)bundleIdentifier
                   completionHandler:(RCNDBLoadCompletion)handler {
  __weak RCNConfigDBManager *weakSelf = self;
  dispatch_async(_databaseOperationQueue, ^{
    RCNConfigDBManager *strongSelf = weakSelf;
    if (!strongSelf) {
      return;
    }
    __block NSDictionary *fetchedConfig =
        [strongSelf loadMainTableWithBundleIdentifier:bundleIdentifier
                                           fromSource:RCNDBSourceFetched];
    __block NSDictionary *activeConfig =
        [strongSelf loadMainTableWithBundleIdentifier:bundleIdentifier
                                           fromSource:RCNDBSourceActive];
    __block NSDictionary *defaultConfig =
        [strongSelf loadMainTableWithBundleIdentifier:bundleIdentifier
                                           fromSource:RCNDBSourceDefault];
    if (handler) {
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        fetchedConfig = fetchedConfig ? fetchedConfig : [[NSDictionary alloc] init];
        activeConfig = activeConfig ? activeConfig : [[NSDictionary alloc] init];
        defaultConfig = defaultConfig ? defaultConfig : [[NSDictionary alloc] init];
        handler(YES, fetchedConfig, activeConfig, defaultConfig);
      });
    }
  });
}

- (NSMutableDictionary *)loadMainTableWithBundleIdentifier:(NSString *)bundleIdentifier
                                                fromSource:(RCNDBSource)source {
  NSMutableDictionary *namespaceToConfig = [[NSMutableDictionary alloc] init];
  const char *SQL = "SELECT bundle_identifier, namespace, key, value FROM " RCNTableNameMain
                    " WHERE bundle_identifier = ?";
  if (source == RCNDBSourceDefault) {
    SQL = "SELECT bundle_identifier, namespace, key, value FROM " RCNTableNameMainDefault
          " WHERE bundle_identifier = ?";
  } else if (source == RCNDBSourceActive) {
    SQL = "SELECT bundle_identifier, namespace, key, value FROM " RCNTableNameMainActive
          " WHERE bundle_identifier = ?";
  }
  NSArray *params = @[ bundleIdentifier ];
  sqlite3_stmt *statement = [self prepareSQL:SQL];
  if (!statement) {
    return nil;
  }
  [self bindStringsToStatement:statement stringArray:params];

  while (sqlite3_step(statement) == SQLITE_ROW) {
    NSString *configNamespace =
        [[NSString alloc] initWithUTF8String:(char *)sqlite3_column_text(statement, 1)];
    NSString *key = [[NSString alloc] initWithUTF8String:(char *)sqlite3_column_text(statement, 2)];
    NSData *value = [NSData dataWithBytes:(char *)sqlite3_column_blob(statement, 3)
                                   length:sqlite3_column_bytes(statement, 3)];
    if (!namespaceToConfig[configNamespace]) {
      namespaceToConfig[configNamespace] = [[NSMutableDictionary alloc] init];
    }

    if (source == RCNDBSourceDefault) {
      namespaceToConfig[configNamespace][key] =
          [[FIRRemoteConfigValue alloc] initWithData:value source:FIRRemoteConfigSourceDefault];
    } else {
      namespaceToConfig[configNamespace][key] =
          [[FIRRemoteConfigValue alloc] initWithData:value source:FIRRemoteConfigSourceRemote];
    }
  }
  sqlite3_finalize(statement);
  return namespaceToConfig;
}

#pragma mark - delete
- (void)deleteRecordFromMainTableWithNamespace:(NSString *)namespace_p
                              bundleIdentifier:(NSString *)bundleIdentifier
                                    fromSource:(RCNDBSource)source {
  __weak RCNConfigDBManager *weakSelf = self;
  dispatch_async(_databaseOperationQueue, ^{
    RCNConfigDBManager *strongSelf = weakSelf;
    if (!strongSelf) {
      return;
    }
    NSArray *params = @[ bundleIdentifier, namespace_p ];
    const char *SQL =
        "DELETE FROM " RCNTableNameMain " WHERE bundle_identifier = ? and namespace = ?";
    if (source == RCNDBSourceDefault) {
      SQL = "DELETE FROM " RCNTableNameMainDefault " WHERE bundle_identifier = ? and namespace = ?";
    } else if (source == RCNDBSourceActive) {
      SQL = "DELETE FROM " RCNTableNameMainActive " WHERE bundle_identifier = ? and namespace = ?";
    }
    [strongSelf executeQuery:SQL withParams:params];
  });
}

- (void)deleteRecordWithBundleIdentifier:(NSString *)bundleIdentifier
                            isInternalDB:(BOOL)isInternalDB {
  __weak RCNConfigDBManager *weakSelf = self;
  dispatch_async(_databaseOperationQueue, ^{
    RCNConfigDBManager *strongSelf = weakSelf;
    if (!strongSelf) {
      return;
    }
    const char *SQL = "DELETE FROM " RCNTableNameInternalMetadata " WHERE key LIKE ?";
    if (!isInternalDB) {
      SQL = "DELETE FROM " RCNTableNameMetadata " WHERE bundle_identifier = ?";
    }
    NSArray *params = @[ bundleIdentifier ];
    [strongSelf executeQuery:SQL withParams:params];
  });
}

- (void)deleteAllRecordsFromTableWithSource:(RCNDBSource)source {
  __weak RCNConfigDBManager *weakSelf = self;
  dispatch_async(_databaseOperationQueue, ^{
    RCNConfigDBManager *strongSelf = weakSelf;
    if (!strongSelf) {
      return;
    }
    const char *SQL = "DELETE FROM " RCNTableNameMain;
    if (source == RCNDBSourceDefault) {
      SQL = "DELETE FROM " RCNTableNameMainDefault;
    } else if (source == RCNDBSourceActive) {
      SQL = "DELETE FROM " RCNTableNameMainActive;
    }
    [strongSelf executeQuery:SQL];
  });
}

- (void)deleteExperimentTableForKey:(NSString *)key {
  __weak RCNConfigDBManager *weakSelf = self;
  dispatch_async(_databaseOperationQueue, ^{
    RCNConfigDBManager *strongSelf = weakSelf;
    if (!strongSelf) {
      return;
    }
    NSArray *params = @[ key ];
    const char *SQL = "DELETE FROM " RCNTableNameExperiment " WHERE key = ?";
    [strongSelf executeQuery:SQL withParams:params];
  });
}

#pragma mark - helper
- (BOOL)executeQuery:(const char *)SQL withParams:(NSArray *)params {
  RCN_MUST_NOT_BE_MAIN_THREAD();
  sqlite3_stmt *statement = [self prepareSQL:SQL];
  if (!statement) {
    return NO;
  }

  [self bindStringsToStatement:statement stringArray:params];
  if (sqlite3_step(statement) != SQLITE_DONE) {
    return [self logErrorWithSQL:SQL finalizeStatement:statement returnValue:NO];
  }
  sqlite3_finalize(statement);
  return YES;
}

/// Params only accept TEXT format string.
- (BOOL)bindStringsToStatement:(sqlite3_stmt *)statement stringArray:(NSArray *)array {
  int index = 1;
  for (NSString *param in array) {
    if (![self bindStringToStatement:statement index:index string:param]) {
      return [self logErrorWithSQL:nil finalizeStatement:statement returnValue:NO];
    }
    index++;
  }
  return YES;
}

- (BOOL)bindStringToStatement:(sqlite3_stmt *)statement index:(int)index string:(NSString *)value {
  if (sqlite3_bind_text(statement, index, [value UTF8String], -1, SQLITE_TRANSIENT) != SQLITE_OK) {
    return [self logErrorWithSQL:nil finalizeStatement:statement returnValue:NO];
  }
  return YES;
}

- (sqlite3_stmt *)prepareSQL:(const char *)SQL {
  sqlite3_stmt *statement = nil;
  if (sqlite3_prepare_v2(_database, SQL, -1, &statement, NULL) != SQLITE_OK) {
    [self logErrorWithSQL:SQL finalizeStatement:statement returnValue:NO];
    return nil;
  }
  return statement;
}

- (NSString *)errorMessage {
  return [NSString stringWithFormat:@"%s", sqlite3_errmsg(_database)];
}

- (int)errorCode {
  return sqlite3_errcode(_database);
}

- (void)logDatabaseError {
  FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000015", @"Error message: %@. Error code: %d.",
              [self errorMessage], [self errorCode]);
}

- (BOOL)logErrorWithSQL:(const char *)SQL
      finalizeStatement:(sqlite3_stmt *)statement
            returnValue:(BOOL)returnValue {
  if (SQL) {
    FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000016", @"Failed with SQL: %s.", SQL);
  }
  [self logDatabaseError];

  if (statement) {
    sqlite3_finalize(statement);
  }

  return returnValue;
}

@end
