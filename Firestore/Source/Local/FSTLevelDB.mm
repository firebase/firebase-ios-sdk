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
#import "Firestore/Source/Core/FSTListenSequence.h"
#import "Firestore/Source/Local/FSTLRUGarbageCollector.h"
#import "Firestore/Source/Local/FSTLevelDBKey.h"
#import "Firestore/Source/Local/FSTLevelDBMigrations.h"
#import "Firestore/Source/Local/FSTLevelDBMutationQueue.h"
#import "Firestore/Source/Local/FSTLevelDBQueryCache.h"
#import "Firestore/Source/Local/FSTLevelDBRemoteDocumentCache.h"
#import "Firestore/Source/Local/FSTReferenceSet.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"

#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_transaction.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/ordered_code.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/src/firebase/firestore/util/string_util.h"
#include "absl/memory/memory.h"
#include "absl/strings/match.h"
#include "leveldb/db.h"

namespace util = firebase::firestore::util;
using firebase::firestore::auth::User;
using firebase::firestore::core::DatabaseInfo;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::ResourcePath;
using util::OrderedCode;

NS_ASSUME_NONNULL_BEGIN

static NSString *const kReservedPathComponent = @"firestore";

using firebase::firestore::local::LevelDbTransaction;
using leveldb::DB;
using leveldb::Options;
using leveldb::ReadOptions;
using leveldb::Status;
using leveldb::WriteOptions;

/**
 * Provides LRU functionality for leveldb persistence.
 *
 * Although this could implement FSTTransactional, it doesn't because it is not directly tied to
 * a transaction runner, it just happens to be called from FSTLevelDB, which is FSTTransactional.
 */
@interface FSTLevelDBLRUDelegate : NSObject <FSTReferenceDelegate, FSTLRUDelegate>

- (void)transactionWillStart;

- (void)transactionWillCommit;

- (void)start;

@end

@implementation FSTLevelDBLRUDelegate {
  FSTLRUGarbageCollector *_gc;
  // This delegate should have the same lifetime as the persistence layer, but mark as
  // weak to avoid retain cycle.
  __weak FSTLevelDB *_db;
  FSTReferenceSet *_additionalReferences;
  FSTListenSequenceNumber _currentSequenceNumber;
  FSTListenSequence *_listenSequence;
}

- (instancetype)initWithPersistence:(FSTLevelDB *)persistence {
  if (self = [super init]) {
    _gc =
        [[FSTLRUGarbageCollector alloc] initWithQueryCache:[persistence queryCache] delegate:self];
    _db = persistence;
    _currentSequenceNumber = kFSTListenSequenceNumberInvalid;
  }
  return self;
}

- (void)start {
  FSTListenSequenceNumber highestSequenceNumber = _db.queryCache.highestListenSequenceNumber;
  _listenSequence = [[FSTListenSequence alloc] initStartingAfter:highestSequenceNumber];
}

- (void)transactionWillStart {
  HARD_ASSERT(_currentSequenceNumber == kFSTListenSequenceNumberInvalid,
              "Previous sequence number is still in effect");
  _currentSequenceNumber = [_listenSequence next];
}

- (void)transactionWillCommit {
  _currentSequenceNumber = kFSTListenSequenceNumberInvalid;
}

- (FSTListenSequenceNumber)currentSequenceNumber {
  HARD_ASSERT(_currentSequenceNumber != kFSTListenSequenceNumberInvalid,
              "Asking for a sequence number outside of a transaction");
  return _currentSequenceNumber;
}

- (void)addInMemoryPins:(FSTReferenceSet *)set {
  // We should be able to assert that _additionalReferences is nil, but due to restarts in spec
  // tests it would fail.
  _additionalReferences = set;
}

- (void)removeTarget:(FSTQueryData *)queryData {
  FSTQueryData *updated =
      [queryData queryDataByReplacingSnapshotVersion:queryData.snapshotVersion
                                         resumeToken:queryData.resumeToken
                                      sequenceNumber:[self currentSequenceNumber]];
  [_db.queryCache updateQueryData:updated];
}

- (void)addReference:(const DocumentKey &)key {
  [self writeSentinelForKey:key];
}

- (void)removeReference:(const DocumentKey &)key {
  [self writeSentinelForKey:key];
}

- (BOOL)mutationQueuesContainKey:(const DocumentKey &)docKey {
  const std::set<std::string> &users = _db.users;
  const ResourcePath &path = docKey.path();
  std::string buffer;
  auto it = _db.currentTransaction->NewIterator();
  // For each user, if there is any batch that contains this document in any batch, we know it's
  // pinned.
  for (auto user = users.begin(); user != users.end(); ++user) {
    std::string mutationKey =
        [FSTLevelDBDocumentMutationKey keyPrefixWithUserID:*user resourcePath:path];
    it->Seek(mutationKey);
    if (it->Valid() && absl::StartsWith(it->key(), mutationKey)) {
      return YES;
    }
  }
  return NO;
}

- (BOOL)isPinned:(const DocumentKey &)docKey {
  if ([_additionalReferences containsKey:docKey]) {
    return YES;
  }
  if ([self mutationQueuesContainKey:docKey]) {
    return YES;
  }
  return NO;
}

- (void)enumerateTargetsUsingBlock:(void (^)(FSTQueryData *queryData, BOOL *stop))block {
  FSTLevelDBQueryCache *queryCache = _db.queryCache;
  [queryCache enumerateTargetsUsingBlock:block];
}

- (void)enumerateMutationsUsingBlock:
    (void (^)(const DocumentKey &key, FSTListenSequenceNumber sequenceNumber, BOOL *stop))block {
  FSTLevelDBQueryCache *queryCache = _db.queryCache;
  [queryCache enumerateOrphanedDocumentsUsingBlock:block];
}

- (int)removeOrphanedDocumentsThroughSequenceNumber:(FSTListenSequenceNumber)upperBound {
  FSTLevelDBQueryCache *queryCache = _db.queryCache;
  __block int count = 0;
  [queryCache enumerateOrphanedDocumentsUsingBlock:^(
                  const DocumentKey &docKey, FSTListenSequenceNumber sequenceNumber, BOOL *stop) {
    if (sequenceNumber <= upperBound) {
      if (![self isPinned:docKey]) {
        count++;
        [self->_db.remoteDocumentCache removeEntryForKey:docKey];
      }
    }
  }];
  return count;
}

- (int)removeTargetsThroughSequenceNumber:(FSTListenSequenceNumber)sequenceNumber
                              liveQueries:(NSDictionary<NSNumber *, FSTQueryData *> *)liveQueries {
  FSTLevelDBQueryCache *queryCache = _db.queryCache;
  return [queryCache removeQueriesThroughSequenceNumber:sequenceNumber liveQueries:liveQueries];
}

- (FSTLRUGarbageCollector *)gc {
  return _gc;
}

- (void)writeSentinelForKey:(const DocumentKey &)key {
  std::string encodedSequenceNumber;
  OrderedCode::WriteSignedNumIncreasing(&encodedSequenceNumber, [self currentSequenceNumber]);
  std::string sentinelKey = [FSTLevelDBDocumentTargetKey sentinelKeyWithDocumentKey:key];
  _db.currentTransaction->Put(sentinelKey, encodedSequenceNumber);
}

- (void)removeMutationReference:(const DocumentKey &)key {
  [self writeSentinelForKey:key];
}

- (void)limboDocumentUpdated:(const DocumentKey &)key {
  [self writeSentinelForKey:key];
}

@end

@interface FSTLevelDB ()

@property(nonatomic, copy) NSString *directory;
@property(nonatomic, assign, getter=isStarted) BOOL started;
@property(nonatomic, strong, readonly) FSTLocalSerializer *serializer;

@end

@implementation FSTLevelDB {
  std::unique_ptr<LevelDbTransaction> _transaction;
  std::unique_ptr<leveldb::DB> _ptr;
  FSTTransactionRunner _transactionRunner;
  FSTLevelDBLRUDelegate *_referenceDelegate;
  FSTLevelDBQueryCache *_queryCache;
  std::set<std::string> _users;
}

/**
 * For now this is paranoid, but perhaps disable that in production builds.
 */
+ (const ReadOptions)standardReadOptions {
  ReadOptions options;
  options.verify_checksums = true;
  return options;
}

+ (std::set<std::string>)collectUserSet:(LevelDbTransaction *)transaction {
  std::set<std::string> users;

  std::string tablePrefix = [FSTLevelDBMutationKey keyPrefix];
  auto it = transaction->NewIterator();
  it->Seek(tablePrefix);
  FSTLevelDBMutationKey *rowKey = [[FSTLevelDBMutationKey alloc] init];
  while (it->Valid() && absl::StartsWith(it->key(), tablePrefix) && [rowKey decodeKey:it->key()]) {
    users.insert(rowKey.userID);

    auto userEnd = [FSTLevelDBMutationKey keyPrefixWithUserID:rowKey.userID];
    userEnd = util::PrefixSuccessor(userEnd);
    it->Seek(userEnd);
  }
  return users;
}

- (instancetype)initWithDirectory:(NSString *)directory
                       serializer:(FSTLocalSerializer *)serializer {
  if (self = [super init]) {
    _directory = [directory copy];
    _serializer = serializer;
    _queryCache = [[FSTLevelDBQueryCache alloc] initWithDB:self serializer:self.serializer];
    _referenceDelegate = [[FSTLevelDBLRUDelegate alloc] initWithPersistence:self];
    _transactionRunner.SetBackingPersistence(self);
  }
  return self;
}

- (const std::set<std::string> &)users {
  return _users;
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
  [FSTLevelDBMigrations runMigrationsWithDatabase:_ptr.get()];
  LevelDbTransaction transaction(_ptr.get(), "Start LevelDB");
  _users = [FSTLevelDB collectUserSet:&transaction];
  transaction.Commit();
  [_queryCache start];
  [_referenceDelegate start];
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
  _users.insert(user.uid());
  return [FSTLevelDBMutationQueue mutationQueueWithUser:user db:self serializer:self.serializer];
}

- (id<FSTQueryCache>)queryCache {
  return _queryCache;
}

- (id<FSTRemoteDocumentCache>)remoteDocumentCache {
  return [[FSTLevelDBRemoteDocumentCache alloc] initWithDB:self serializer:self.serializer];
}

- (void)startTransaction:(absl::string_view)label {
  HARD_ASSERT(_transaction == nullptr, "Starting a transaction while one is already outstanding");
  _transaction = absl::make_unique<LevelDbTransaction>(_ptr.get(), label);
  [_referenceDelegate transactionWillStart];
}

- (void)commitTransaction {
  HARD_ASSERT(_transaction != nullptr, "Committing a transaction before one is started");
  [_referenceDelegate transactionWillCommit];
  _transaction->Commit();
  _transaction.reset();
}

- (void)shutdown {
  HARD_ASSERT(self.isStarted, "FSTLevelDB shutdown without start!");
  self.started = NO;
  _ptr.reset();
}

- (id<FSTReferenceDelegate>)referenceDelegate {
  return _referenceDelegate;
}

- (FSTListenSequenceNumber)currentSequenceNumber {
  return [_referenceDelegate currentSequenceNumber];
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
