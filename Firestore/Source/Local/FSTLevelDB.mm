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

#import "Firestore/Source/Local/FSTLevelDB.h"

#include <memory>
#include <utility>

#import "FIRFirestoreErrors.h"
#import "Firestore/Source/Local/FSTLevelDBMigrations.h"
#import "Firestore/Source/Local/FSTLevelDBMutationQueue.h"
#import "Firestore/Source/Local/FSTLevelDBQueryCache.h"
#import "Firestore/Source/Local/FSTLevelDBRemoteDocumentCache.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"

#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_transaction.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "absl/memory/memory.h"
#include "leveldb/db.h"

namespace util = firebase::firestore::util;
using firebase::firestore::auth::User;
using firebase::firestore::core::DatabaseInfo;
using firebase::firestore::model::DatabaseId;

NS_ASSUME_NONNULL_BEGIN

static NSString *const kReservedPathComponent = @"firestore";

using firebase::firestore::local::LevelDbTransaction;
using leveldb::DB;
using leveldb::Options;
using leveldb::ReadOptions;
using leveldb::Status;
using leveldb::WriteOptions;

@interface FSTLevelDB ()

@property(nonatomic, copy) NSString *directory;
@property(nonatomic, assign, getter=isStarted) BOOL started;
@property(nonatomic, strong, readonly) FSTLocalSerializer *serializer;

@end

@implementation FSTLevelDB {
  std::unique_ptr<LevelDbTransaction> _transaction;
  std::unique_ptr<leveldb::DB> _ptr;
  FSTTransactionRunner _transactionRunner;
}

/**
 * For now this is paranoid, but perhaps disable that in production builds.
 */
+ (const ReadOptions)standardReadOptions {
  ReadOptions options;
  options.verify_checksums = true;
  return options;
}

- (instancetype)initWithDirectory:(NSString *)directory
                       serializer:(FSTLocalSerializer *)serializer {
  if (self = [super init]) {
    _directory = [directory copy];
    _serializer = serializer;
    _transactionRunner.SetBackingPersistence(self);
  }
  return self;
}

- (leveldb::DB *)ptr {
  return _ptr.get();
}

- (const FSTTransactionRunner &)run {
  return _transactionRunner;
}

+ (NSString *)documentsDirectory {
#if TARGET_OS_IPHONE
  NSArray<NSString *> *directories =
      NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  return [directories[0] stringByAppendingPathComponent:kReservedPathComponent];

#elif TARGET_OS_MAC
  NSString *dotPrefixed = [@"." stringByAppendingString:kReservedPathComponent];
  return [NSHomeDirectory() stringByAppendingPathComponent:dotPrefixed];

#else
#error "local storage on tvOS"
  // TODO(mcg): Writing to NSDocumentsDirectory on tvOS will fail; we need to write to Caches
  // https://developer.apple.com/library/content/documentation/General/Conceptual/AppleTV_PG/

#endif
}

+ (NSString *)storageDirectoryForDatabaseInfo:(const DatabaseInfo &)databaseInfo
                           documentsDirectory:(NSString *)documentsDirectory {
  // Use two different path formats:
  //
  //   * persistenceKey / projectID . databaseID / name
  //   * persistenceKey / projectID / name
  //
  // projectIDs are DNS-compatible names and cannot contain dots so there's
  // no danger of collisions.
  NSString *directory = documentsDirectory;
  directory =
      [directory stringByAppendingPathComponent:util::WrapNSString(databaseInfo.persistence_key())];

  NSString *segment = util::WrapNSString(databaseInfo.database_id().project_id());
  if (!databaseInfo.database_id().IsDefaultDatabase()) {
    segment = [NSString
        stringWithFormat:@"%@.%s", segment, databaseInfo.database_id().database_id().c_str()];
  }
  directory = [directory stringByAppendingPathComponent:segment];

  // Reserve one additional path component to allow multiple physical databases
  directory = [directory stringByAppendingPathComponent:@"main"];
  return directory;
}

#pragma mark - Startup

- (BOOL)start:(NSError **)error {
  HARD_ASSERT(!self.isStarted, "FSTLevelDB double-started!");
  self.started = YES;
  NSString *directory = self.directory;
  if (![self ensureDirectory:directory error:error]) {
    return NO;
  }

  DB *database = [self createDBWithDirectory:directory error:error];
  if (!database) {
    return NO;
  }
  _ptr.reset(database);
  LevelDbTransaction transaction(_ptr.get(), "Start LevelDB");
  [FSTLevelDBMigrations runMigrationsWithTransaction:&transaction];
  transaction.Commit();
  return YES;
}

/** Creates the directory at @a directory and marks it as excluded from iCloud backup. */
- (BOOL)ensureDirectory:(NSString *)directory error:(NSError **)error {
  NSError *localError;
  NSFileManager *files = [NSFileManager defaultManager];

  BOOL success = [files createDirectoryAtPath:directory
                  withIntermediateDirectories:YES
                                   attributes:nil
                                        error:&localError];
  if (!success) {
    *error =
        [NSError errorWithDomain:FIRFirestoreErrorDomain
                            code:FIRFirestoreErrorCodeInternal
                        userInfo:@{
                          NSLocalizedDescriptionKey : @"Failed to create persistence directory",
                          NSUnderlyingErrorKey : localError
                        }];
    return NO;
  }

  NSURL *dirURL = [NSURL fileURLWithPath:directory];
  success = [dirURL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:&localError];
  if (!success) {
    *error = [NSError errorWithDomain:FIRFirestoreErrorDomain
                                 code:FIRFirestoreErrorCodeInternal
                             userInfo:@{
                               NSLocalizedDescriptionKey :
                                   @"Failed mark persistence directory as excluded from backups",
                               NSUnderlyingErrorKey : localError
                             }];
    return NO;
  }

  return YES;
}

/** Opens the database within the given directory. */
- (nullable DB *)createDBWithDirectory:(NSString *)directory error:(NSError **)error {
  Options options;
  options.create_if_missing = true;

  DB *database;
  Status status = DB::Open(options, [directory UTF8String], &database);
  if (!status.ok()) {
    if (error) {
      NSString *name = [directory lastPathComponent];
      *error =
          [FSTLevelDB errorWithStatus:status
                          description:@"Failed to create database %@ at path %@", name, directory];
    }
    return nullptr;
  }

  return database;
}

- (LevelDbTransaction *)currentTransaction {
  HARD_ASSERT(_transaction != nullptr, "Attempting to access transaction before one has started");
  return _transaction.get();
}

#pragma mark - Persistence Factory methods

- (id<FSTMutationQueue>)mutationQueueForUser:(const User &)user {
  return [FSTLevelDBMutationQueue mutationQueueWithUser:user db:self serializer:self.serializer];
}

- (id<FSTQueryCache>)queryCache {
  return [[FSTLevelDBQueryCache alloc] initWithDB:self serializer:self.serializer];
}

- (id<FSTRemoteDocumentCache>)remoteDocumentCache {
  return [[FSTLevelDBRemoteDocumentCache alloc] initWithDB:self serializer:self.serializer];
}

- (void)startTransaction:(absl::string_view)label {
  HARD_ASSERT(_transaction == nullptr, "Starting a transaction while one is already outstanding");
  _transaction = absl::make_unique<LevelDbTransaction>(_ptr.get(), label);
}

- (void)commitTransaction {
  HARD_ASSERT(_transaction != nullptr, "Committing a transaction before one is started");
  _transaction->Commit();
  _transaction.reset();
}

- (void)shutdown {
  HARD_ASSERT(self.isStarted, "FSTLevelDB shutdown without start!");
  self.started = NO;
  _ptr.reset();
}

- (_Nullable id<FSTReferenceDelegate>)referenceDelegate {
  return nil;
}

#pragma mark - Error and Status

+ (nullable NSError *)errorWithStatus:(Status)status description:(NSString *)description, ... {
  if (status.ok()) {
    return nil;
  }

  va_list args;
  va_start(args, description);

  NSString *message = [[NSString alloc] initWithFormat:description arguments:args];
  NSString *reason = [self descriptionOfStatus:status];
  NSError *result = [NSError errorWithDomain:FIRFirestoreErrorDomain
                                        code:FIRFirestoreErrorCodeInternal
                                    userInfo:@{
                                      NSLocalizedDescriptionKey : message,
                                      NSLocalizedFailureReasonErrorKey : reason
                                    }];

  va_end(args);

  return result;
}

+ (NSString *)descriptionOfStatus:(Status)status {
  return [NSString stringWithCString:status.ToString().c_str() encoding:NSUTF8StringEncoding];
}

@end

NS_ASSUME_NONNULL_END
