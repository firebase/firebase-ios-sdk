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

#import <Foundation/Foundation.h>

#include <memory>
#include <set>
#include <string>

#import "Firestore/Source/Local/FSTPersistence.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_transaction.h"
#include "Firestore/core/src/firebase/firestore/util/path.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "leveldb/db.h"

@class FSTLocalSerializer;

NS_ASSUME_NONNULL_BEGIN

/** A LevelDB-backed instance of FSTPersistence. */
// TODO(mikelehen): Rename to FSTLevelDBPersistence.
@interface FSTLevelDB : NSObject <FSTPersistence, FSTTransactional>

/**
 * Initializes the LevelDB in the given directory. Note that all expensive startup work including
 * opening any database files is deferred until -[FSTPersistence start] is called.
 */
- (instancetype)initWithDirectory:(firebase::firestore::util::Path)directory
                       serializer:(FSTLocalSerializer *)serializer NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/** Finds a suitable directory to serve as the root of all Firestore local storage. */
+ (firebase::firestore::util::Path)documentsDirectory;

/**
 * Computes a unique storage directory for the given identifying components of local storage.
 *
 * @param databaseInfo The identifying information for the local storage instance.
 * @param documentsDirectory The root document directory relative to which the storage directory
 *     will be created. Usually just +[FSTLevelDB documentsDir].
 * @return A storage directory unique to the instance identified by databaseInfo.
 */
+ (firebase::firestore::util::Path)
    storageDirectoryForDatabaseInfo:(const firebase::firestore::core::DatabaseInfo &)databaseInfo
                 documentsDirectory:(const firebase::firestore::util::Path &)documentsDirectory;

/**
 * Starts LevelDB-backed persistent storage by opening the database files, creating the DB if it
 * does not exist.
 *
 * The leveldb directory is created relative to the appropriate document storage directory for the
 * platform: NSDocumentDirectory on iOS or $HOME/.firestore on macOS.
 */
- (firebase::firestore::util::Status)start;

/**
 * @return A standard set of read options
 */
+ (const leveldb::ReadOptions)standardReadOptions;

/** The native db pointer, allocated during start. */
@property(nonatomic, assign, readonly) leveldb::DB *ptr;

@property(nonatomic, readonly) firebase::firestore::local::LevelDbTransaction *currentTransaction;

@property(nonatomic, readonly) const std::set<std::string> &users;

@end

NS_ASSUME_NONNULL_END
