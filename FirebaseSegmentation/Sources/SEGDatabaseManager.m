// Copyright 2019 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "SEGDatabaseManager.h"

#import <FirebaseCore/FIRLogger.h>
#import <sqlite3.h>

/// SQLite file name.
static NSString *const kDatabaseName = @"FirebaseSegmentation.sqlite3";
/// The application support sub-directory that the Segmentation database resides in.
static NSString *const kApplicationSupportSubDirectory = @"Google/FirebaseSegmentation";
/// Column names
static NSString *const kMainTableName = @"main";
static NSString *const kMainTableColumnApplicationIdentifier = @"firebase_app_identifier";
static NSString *const kMainTableColumnCustomInstallationIdentifier =
    @"custom_installation_identifier";
static NSString *const kMainTableColumnFirebaseInstallationIdentifier =
    @"firebase_installation_identifier";
static NSString *const kMainTableColumnAssociationStatus = @"association_status";

// Exclude the database from iCloud backup.
static BOOL SegmentationAddSkipBackupAttributeToItemAtPath(NSString *filePathString) {
  NSURL *URL = [NSURL fileURLWithPath:filePathString];
  assert([[NSFileManager defaultManager] fileExistsAtPath:[URL path]]);

  NSError *error = nil;
  BOOL success = [URL setResourceValue:[NSNumber numberWithBool:YES]
                                forKey:NSURLIsExcludedFromBackupKey
                                 error:&error];
  if (!success) {
    // TODO(dmandar): log error.
    NSLog(@"Error excluding %@ from backup %@.", [URL lastPathComponent], error);
  }
  return success;
}

static BOOL SegmentationCreateFilePathIfNotExist(NSString *filePath) {
  if (!filePath || !filePath.length) {
    // TODO(dmandar) log error.
    NSLog(@"Failed to create subdirectory for an empty file path.");
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
      // TODO(dmandar) log error.
      NSLog(@"Failed to create subdirectory for database file: %@.", error);
      return NO;
    }
  }
  return YES;
}

@interface SEGDatabaseManager () {
  /// Database storing all the config information.
  sqlite3 *_database;
  /// Serial queue for database read/write operations.
  dispatch_queue_t _databaseOperationQueue;
}
@end

@implementation SEGDatabaseManager

+ (instancetype)sharedInstance {
  static dispatch_once_t onceToken;
  static SEGDatabaseManager *sharedInstance;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[SEGDatabaseManager alloc] init];
  });
  return sharedInstance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _databaseOperationQueue =
        dispatch_queue_create("com.google.firebasesegmentation.database", DISPATCH_QUEUE_SERIAL);
  }
  return self;
}

#pragma mark - Public Methods

- (void)loadMainTableWithCompletion:(SEGRequestCompletion)completionHandler {
  __weak SEGDatabaseManager *weakSelf = self;
  dispatch_async(_databaseOperationQueue, ^{
    SEGDatabaseManager *strongSelf = weakSelf;
    if (!strongSelf) {
      completionHandler(NO, @{@"Database Error" : @"Internal database error"});
    }

    // Read the database into memory.
    NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *associations =
        [self loadMainTable];
    completionHandler(YES, associations);
  });
  return;
}

- (void)createOrOpenDatabaseWithCompletion:(SEGRequestCompletion)completionHandler {
  __weak SEGDatabaseManager *weakSelf = self;
  dispatch_async(_databaseOperationQueue, ^{
    SEGDatabaseManager *strongSelf = weakSelf;
    if (!strongSelf) {
      completionHandler(NO, @{@"ErrorDescription" : @"Internal database error"});
    }
    NSString *dbPath = [SEGDatabaseManager pathForSegmentationDatabase];
    // TODO(dmandar) log.
    NSLog(@"Loading segmentation database at path %@", dbPath);
    const char *databasePath = dbPath.UTF8String;
    // Create or open database path.
    if (!SegmentationCreateFilePathIfNotExist(dbPath)) {
      completionHandler(NO, @{@"ErrorDescription" : @"Could not create database file at path"});
    }
    int flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FILEPROTECTION_COMPLETE |
                SQLITE_OPEN_FULLMUTEX;
    if (sqlite3_open_v2(databasePath, &strongSelf->_database, flags, NULL) == SQLITE_OK) {
      // Create table if does not exist already.
      if ([strongSelf createTableSchema]) {
        // DB file created or already exists.
        // Exclude the app data used from iCloud backup.
        SegmentationAddSkipBackupAttributeToItemAtPath(dbPath);

        // Read the database into memory.
        NSDictionary<NSString *, NSString *> *associations = [self loadMainTable];
        completionHandler(YES, associations);

      } else {
        // Remove database before fail.
        [strongSelf removeDatabase:dbPath];
        FIRLogError(kFIRLoggerSegmentation, @"I-SEG000010", @"Failed to create table.");
        // Create a new database if existing database file is corrupted.
        if (!SegmentationCreateFilePathIfNotExist(dbPath)) {
          completionHandler(NO,
                            @{@"ErrorDescription" : @"Could not recreate database file at path"});
        }
        if (sqlite3_open_v2(databasePath, &strongSelf->_database, flags, NULL) == SQLITE_OK) {
          if (![strongSelf createTableSchema]) {
            // Remove database before fail.
            [strongSelf removeDatabase:dbPath];
            // If it failed again, there's nothing we can do here.
            FIRLogError(kFIRLoggerSegmentation, @"I-SEG000010", @"Failed to create table.");
          } else {
            // Exclude the app data used from iCloud backup.
            SegmentationAddSkipBackupAttributeToItemAtPath(dbPath);
          }
        } else {
          [strongSelf logDatabaseError];
          completionHandler(NO, @{@"ErrorDescription" : @"Could not create database."});
        }
      }
    } else {
      [strongSelf logDatabaseError];
      completionHandler(NO, @{@"ErrorDescription" : @"Error creating database."});
    }
  });
}

- (void)removeDatabase:(NSString *)path completion:(SEGRequestCompletion)completionHandler {
  __weak SEGDatabaseManager *weakSelf = self;
  dispatch_async(_databaseOperationQueue, ^{
    SEGDatabaseManager *strongSelf = weakSelf;
    if (!strongSelf) {
      return;
    }
    [strongSelf removeDatabase:path];
  });
}

#pragma mark - Private Methods

- (NSDictionary *)loadMainTable {
  NSString *SQLQuery = [NSString
      stringWithFormat:@"SELECT %@, %@, %@, %@ FROM %@", kMainTableColumnApplicationIdentifier,
                       kMainTableColumnCustomInstallationIdentifier,
                       kMainTableColumnFirebaseInstallationIdentifier,
                       kMainTableColumnAssociationStatus, kMainTableName];

  sqlite3_stmt *statement = [self prepareSQL:[SQLQuery cStringUsingEncoding:NSUTF8StringEncoding]];
  if (!statement) {
    return nil;
  }

  NSMutableDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *associations =
      [[NSMutableDictionary alloc] init];
  while (sqlite3_step(statement) == SQLITE_ROW) {
    NSString *firebaseApplicationName =
        [[NSString alloc] initWithUTF8String:(char *)sqlite3_column_text(statement, 0)];
    NSString *customInstallationIdentifier =
        [[NSString alloc] initWithUTF8String:(char *)sqlite3_column_text(statement, 1)];
    NSString *firebaseInstallationIdentifier =
        [[NSString alloc] initWithUTF8String:(char *)sqlite3_column_text(statement, 2)];
    NSString *associationStatus =
        [[NSString alloc] initWithUTF8String:(char *)sqlite3_column_text(statement, 3)];
    NSDictionary<NSString *, NSString *> *associationData = @{
      kSEGCustomInstallationIdentifierKey : customInstallationIdentifier,
      kSEGFirebaseInstallationIdentifierKey : firebaseInstallationIdentifier,
      kSEGAssociationStatusKey : associationStatus
    };
    [associations setObject:associationData forKey:firebaseApplicationName];
  }
  sqlite3_finalize(statement);
  return associations;
}

/// Returns the current version of the Remote Config database.
+ (NSString *)pathForSegmentationDatabase {
  NSArray<NSString *> *dirPaths =
      NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
  NSString *appSupportPath = dirPaths.firstObject;
  NSArray<NSString *> *components =
      @[ appSupportPath, kApplicationSupportSubDirectory, kDatabaseName ];
  return [NSString pathWithComponents:components];
}

- (BOOL)createTableSchema {
  SEG_MUST_NOT_BE_MAIN_THREAD();
  NSString *mainTableSchema =
      [NSString stringWithFormat:@"create TABLE IF NOT EXISTS %@ (_id INTEGER PRIMARY KEY, %@ "
                                 @"TEXT, %@ TEXT, %@ TEXT, %@ TEXT)",
                                 kMainTableName, kMainTableColumnApplicationIdentifier,
                                 kMainTableColumnCustomInstallationIdentifier,
                                 kMainTableColumnFirebaseInstallationIdentifier,
                                 kMainTableColumnAssociationStatus];

  return [self executeQuery:[mainTableSchema cStringUsingEncoding:NSUTF8StringEncoding]];
}

- (void)removeDatabase:(NSString *)path {
  SEG_MUST_NOT_BE_MAIN_THREAD();
  if (sqlite3_close(self->_database) != SQLITE_OK) {
    [self logDatabaseError];
  }
  self->_database = nil;

  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSError *error;
  if (![fileManager removeItemAtPath:path error:&error]) {
    FIRLogError(kFIRLoggerSegmentation, @"I-SEG000011",
                @"Failed to remove database at path %@ for error %@.", path, error);
  }
}

#pragma mark - execute
- (BOOL)executeQuery:(const char *)SQL {
  SEG_MUST_NOT_BE_MAIN_THREAD();
  char *error;
  if (sqlite3_exec(_database, SQL, nil, nil, &error) != SQLITE_OK) {
    FIRLogError(kFIRLoggerSegmentation, @"I-SEG000012", @"Failed to execute query with error %s.",
                error);
    return NO;
  }
  return YES;
}

#pragma mark - insert
- (void)insertMainTableApplicationNamed:(NSString *)firebaseApplication
               customInstanceIdentifier:(NSString *)customInstanceIdentifier
             firebaseInstanceIdentifier:(NSString *)firebaseInstanceIdentifier
                      associationStatus:(NSString *)associationStatus
                      completionHandler:(SEGRequestCompletion)handler {
  // TODO: delete the row first.
  __weak SEGDatabaseManager *weakSelf = self;
  dispatch_async(_databaseOperationQueue, ^{
    NSArray<NSString *> *values =
        [[NSArray alloc] initWithObjects:firebaseApplication, customInstanceIdentifier,
                                         firebaseInstanceIdentifier, associationStatus, nil];
    BOOL success = [weakSelf insertMainTableWithValues:values];
    if (handler) {
      dispatch_async(dispatch_get_main_queue(), ^{
        handler(success, nil);
      });
    }
  });
}

- (BOOL)insertMainTableWithValues:(NSArray<NSString *> *)values {
  SEG_MUST_NOT_BE_MAIN_THREAD();
  if (values.count != 4) {
    FIRLogError(kFIRLoggerSegmentation, @"I-SEG000013",
                @"Failed to insert config record. Wrong number of give parameters, current "
                @"number is %ld, correct number is 4.",
                (long)values.count);
    return NO;
  }
  NSString *SQL = [NSString stringWithFormat:@"INSERT INTO %@ (%@, %@, %@, %@) values (?, ?, ?, ?)",
                                             kMainTableName, kMainTableColumnApplicationIdentifier,
                                             kMainTableColumnCustomInstallationIdentifier,
                                             kMainTableColumnFirebaseInstallationIdentifier,
                                             kMainTableColumnAssociationStatus];

  sqlite3_stmt *statement = [self prepareSQL:[SQL UTF8String]];
  if (!statement) {
    return NO;
  }

  NSString *aString = values[0];
  if (![self bindStringToStatement:statement index:1 string:aString]) {
    return [self logErrorWithSQL:[SQL UTF8String] finalizeStatement:statement returnValue:NO];
  }
  aString = values[1];
  if (![self bindStringToStatement:statement index:2 string:aString]) {
    return [self logErrorWithSQL:[SQL UTF8String] finalizeStatement:statement returnValue:NO];
  }
  aString = values[2];
  if (![self bindStringToStatement:statement index:3 string:aString]) {
    return [self logErrorWithSQL:[SQL UTF8String] finalizeStatement:statement returnValue:NO];
  }
  aString = values[3];
  if (![self bindStringToStatement:statement index:4 string:aString]) {
    return [self logErrorWithSQL:[SQL UTF8String] finalizeStatement:statement returnValue:NO];
  }
  if (sqlite3_step(statement) != SQLITE_DONE) {
    return [self logErrorWithSQL:[SQL UTF8String] finalizeStatement:statement returnValue:NO];
  }
  sqlite3_finalize(statement);
  return YES;
}

/// TODO: (Check if required). Clear the record of given namespace and package name
/// before updating the table.
- (void)deleteRecordFromMainTableWithCustomInstanceIdentifier:
    (nonnull NSString *)customInstanceIdentifier {
}

/// TODO: (Check if required). Remove all the records from a config content table.
- (void)deleteAllRecordsFromTable {
}

#pragma mark - helper
- (BOOL)executeQuery:(const char *)SQL withParams:(NSArray *)params {
  SEG_MUST_NOT_BE_MAIN_THREAD();
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
  FIRLogError(kFIRLoggerSegmentation, @"I-SEG000015", @"Error message: %@. Error code: %d.",
              [self errorMessage], [self errorCode]);
}

- (BOOL)logErrorWithSQL:(const char *)SQL
      finalizeStatement:(sqlite3_stmt *)statement
            returnValue:(BOOL)returnValue {
  if (SQL) {
    FIRLogError(kFIRLoggerSegmentation, @"I-SEG000016", @"Failed with SQL: %s.", SQL);
  }
  [self logDatabaseError];

  if (statement) {
    sqlite3_finalize(statement);
  }

  return returnValue;
}

@end
