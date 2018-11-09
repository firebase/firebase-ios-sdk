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
#import "Firestore/Source/Local/FSTLevelDBMutationQueue.h"
#import "Firestore/Source/Local/FSTLevelDBQueryCache.h"
#import "Firestore/Source/Local/FSTLevelDBRemoteDocumentCache.h"
#import "Firestore/Source/Local/FSTReferenceSet.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_key.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_migrations.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_transaction.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_util.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/util/filesystem.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/ordered_code.h"
#include "Firestore/core/src/firebase/firestore/util/statusor.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/src/firebase/firestore/util/string_util.h"
#include "absl/memory/memory.h"
#include "absl/strings/match.h"
#include "absl/strings/str_cat.h"
#include "leveldb/db.h"

NS_ASSUME_NONNULL_BEGIN

namespace util = firebase::firestore::util;
using firebase::firestore::FirestoreErrorCode;
using firebase::firestore::auth::User;
using firebase::firestore::core::DatabaseInfo;
using firebase::firestore::local::ConvertStatus;
using firebase::firestore::local::LevelDbDocumentMutationKey;
using firebase::firestore::local::LevelDbDocumentTargetKey;
using firebase::firestore::local::LevelDbMigrations;
using firebase::firestore::local::LevelDbMutationKey;
using firebase::firestore::local::LevelDbTransaction;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::ListenSequenceNumber;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::util::OrderedCode;
using firebase::firestore::util::Path;
using firebase::firestore::util::Status;
using firebase::firestore::util::StatusOr;
using firebase::firestore::util::StringFormat;
using leveldb::DB;
using leveldb::Options;
using leveldb::ReadOptions;
using leveldb::WriteOptions;

static const char *kReservedPathComponent = "firestore";

@interface FSTLevelDB ()

- (size_t)byteSize;

@property(nonatomic, assign, getter=isStarted) BOOL started;
@property(nonatomic, strong, readonly) FSTLocalSerializer *serializer;

@end

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
  ListenSequenceNumber _currentSequenceNumber;
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
  ListenSequenceNumber highestSequenceNumber = _db.queryCache.highestListenSequenceNumber;
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

- (ListenSequenceNumber)currentSequenceNumber {
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
  for (const std::string &user : users) {
    std::string mutationKey = LevelDbDocumentMutationKey::KeyPrefix(user, path);
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
    (void (^)(const DocumentKey &key, ListenSequenceNumber sequenceNumber, BOOL *stop))block {
  FSTLevelDBQueryCache *queryCache = _db.queryCache;
  [queryCache enumerateOrphanedDocumentsUsingBlock:block];
}

- (int)removeOrphanedDocumentsThroughSequenceNumber:(ListenSequenceNumber)upperBound {
  FSTLevelDBQueryCache *queryCache = _db.queryCache;
  __block int count = 0;
  [queryCache enumerateOrphanedDocumentsUsingBlock:^(
                  const DocumentKey &docKey, ListenSequenceNumber sequenceNumber, BOOL *stop) {
    if (sequenceNumber <= upperBound) {
      if (![self isPinned:docKey]) {
        count++;
        [self->_db.remoteDocumentCache removeEntryForKey:docKey];
        [self removeSentinel:docKey];
      }
    }
  }];
  return count;
}

- (void)removeSentinel:(const DocumentKey &)key {
  _db.currentTransaction->Delete(LevelDbDocumentTargetKey::SentinelKey(key));
}

- (int)removeTargetsThroughSequenceNumber:(ListenSequenceNumber)sequenceNumber
                              liveQueries:(NSDictionary<NSNumber *, FSTQueryData *> *)liveQueries {
  FSTLevelDBQueryCache *queryCache = _db.queryCache;
  return [queryCache removeQueriesThroughSequenceNumber:sequenceNumber liveQueries:liveQueries];
}

- (FSTLRUGarbageCollector *)gc {
  return _gc;
}

- (void)writeSentinelForKey:(const DocumentKey &)key {
  std::string sentinelKey = LevelDbDocumentTargetKey::SentinelKey(key);
  std::string encodedSequenceNumber =
      LevelDbDocumentTargetKey::EncodeSentinelValue([self currentSequenceNumber]);
  _db.currentTransaction->Put(sentinelKey, encodedSequenceNumber);
}

- (void)removeMutationReference:(const DocumentKey &)key {
  [self writeSentinelForKey:key];
}

- (void)limboDocumentUpdated:(const DocumentKey &)key {
  [self writeSentinelForKey:key];
}

- (size_t)byteSize {
  return [_db byteSize];
}

@end

@implementation FSTLevelDB {
  Path _directory;
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

  std::string tablePrefix = LevelDbMutationKey::KeyPrefix();
  auto it = transaction->NewIterator();
  it->Seek(tablePrefix);
  LevelDbMutationKey rowKey;
  while (it->Valid() && absl::StartsWith(it->key(), tablePrefix) && rowKey.Decode(it->key())) {
    users.insert(rowKey.user_id());

    auto userEnd = LevelDbMutationKey::KeyPrefix(rowKey.user_id());
    userEnd = util::PrefixSuccessor(userEnd);
    it->Seek(userEnd);
  }
  return users;
}

- (instancetype)initWithDirectory:(Path)directory serializer:(FSTLocalSerializer *)serializer {
  if (self = [super init]) {
    _directory = std::move(directory);
    _serializer = serializer;
    _queryCache = [[FSTLevelDBQueryCache alloc] initWithDB:self serializer:self.serializer];
    _referenceDelegate = [[FSTLevelDBLRUDelegate alloc] initWithPersistence:self];
    _transactionRunner.SetBackingPersistence(self);
  }
  return self;
}

- (size_t)byteSize {
  int64_t count = 0;
  auto iter = util::DirectoryIterator::Create(_directory);
  for (; iter->Valid(); iter->Next()) {
    int64_t fileSize = util::FileSize(iter->file()).ValueOrDie();
    count += fileSize;
  }
  HARD_ASSERT(iter->status().ok(), "Failed to iterate leveldb directory: %s",
              iter->status().error_message().c_str());
  HARD_ASSERT(count <= SIZE_MAX, "Overflowed counting bytes cached");
  return count;
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

+ (Path)documentsDirectory {
#if TARGET_OS_IPHONE
  NSArray<NSString *> *directories =
      NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  return Path::FromNSString(directories[0]).AppendUtf8(kReservedPathComponent);

#elif TARGET_OS_MAC
  std::string dotPrefixed = absl::StrCat(".", kReservedPathComponent);
  return Path::FromNSString(NSHomeDirectory()).AppendUtf8(dotPrefixed);

#else
#error "local storage on tvOS"
  // TODO(mcg): Writing to NSDocumentsDirectory on tvOS will fail; we need to write to Caches
  // https://developer.apple.com/library/content/documentation/General/Conceptual/AppleTV_PG/

#endif
}

+ (Path)storageDirectoryForDatabaseInfo:(const DatabaseInfo &)databaseInfo
                     documentsDirectory:(const Path &)documentsDirectory {
  // Use two different path formats:
  //
  //   * persistenceKey / projectID . databaseID / name
  //   * persistenceKey / projectID / name
  //
  // projectIDs are DNS-compatible names and cannot contain dots so there's
  // no danger of collisions.
  std::string project_key = databaseInfo.database_id().project_id();
  if (!databaseInfo.database_id().IsDefaultDatabase()) {
    absl::StrAppend(&project_key, ".", databaseInfo.database_id().database_id());
  }

  // Reserve one additional path component to allow multiple physical databases
  return Path::JoinUtf8(documentsDirectory, databaseInfo.persistence_key(), project_key, "main");
}

#pragma mark - Startup

- (Status)start {
  HARD_ASSERT(!self.isStarted, "FSTLevelDB double-started!");
  self.started = YES;

  Status status = [self ensureDirectory:_directory];
  if (!status.ok()) return status;

  StatusOr<std::unique_ptr<DB>> database = [self createDBWithDirectory:_directory];
  if (!database.status().ok()) {
    return database.status();
  }
  _ptr = std::move(database).ValueOrDie();

  LevelDbMigrations::RunMigrations(_ptr.get());
  LevelDbTransaction transaction(_ptr.get(), "Start LevelDB");
  _users = [FSTLevelDB collectUserSet:&transaction];
  transaction.Commit();
  [_queryCache start];
  [_referenceDelegate start];
  return Status::OK();
}

/** Creates the directory at @a directory and marks it as excluded from iCloud backup. */
- (Status)ensureDirectory:(const Path &)directory {
  Status status = util::RecursivelyCreateDir(directory);
  if (!status.ok()) {
    return Status{FirestoreErrorCode::Internal, "Failed to create persistence directory"}.CausedBy(
        status);
  }

  NSURL *dirURL = [NSURL fileURLWithPath:directory.ToNSString()];
  NSError *localError = nil;
  if (![dirURL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:&localError]) {
    return Status{FirestoreErrorCode::Internal,
                  "Failed to mark persistence directory as excluded from backups"}
        .CausedBy(Status::FromNSError(localError));
  }

  return Status::OK();
}

/** Opens the database within the given directory. */
- (StatusOr<std::unique_ptr<DB>>)createDBWithDirectory:(const Path &)directory {
  Options options;
  options.create_if_missing = true;

  DB *database = nullptr;
  leveldb::Status status = DB::Open(options, directory.ToUtf8String(), &database);
  if (!status.ok()) {
    return Status{FirestoreErrorCode::Internal,
                  StringFormat("Failed to open LevelDB database at %s", directory.ToUtf8String())}
        .CausedBy(ConvertStatus(status));
  }

  return std::unique_ptr<DB>(database);
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

- (ListenSequenceNumber)currentSequenceNumber {
  return [_referenceDelegate currentSequenceNumber];
}

@end

NS_ASSUME_NONNULL_END
