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
- (instancetype)initWithDirectory:(NSString *)directory
                       serializer:(FSTLocalSerializer *)serializer NS_DESIGNATED_INITIALIZER;

- (instancetype)init __attribute__((unavailable("Use -initWithDirectory: instead.")));

/** Finds a suitable directory to serve as the root of all Firestore local storage. */
+ (NSString *)documentsDirectory;

/**
 * Computes a unique storage directory for the given identifying components of local storage.
 *
 * @param databaseInfo The identifying information for the local storage instance.
 * @param documentsDirectory The root document directory relative to which the storage directory
 *     will be created. Usually just +[FSTLevelDB documentsDir].
 * @return A storage directory unique to the instance identified by databaseInfo.
 */
+ (NSString *)storageDirectoryForDatabaseInfo:
                  (const firebase::firestore::core::DatabaseInfo &)databaseInfo
                           documentsDirectory:(NSString *)documentsDirectory;

/**
 * Starts LevelDB-backed persistent storage by opening the database files, creating the DB if it
 * does not exist.
 *
 * The leveldb directory is created relative to the appropriate document storage directory for the
 * platform: NSDocumentDirectory on iOS or $HOME/.firestore on macOS.
 */
- (BOOL)start:(NSError **)error;

// What follows is the Objective-C++ extension to the API.
/**
 * @return A standard set of read options
 */
+ (const leveldb::ReadOptions)standardReadOptions;

/**
 * Creates an NSError based on the given status if the status is not ok.
 *
 * @param status The status of the preceding LevelDB operation.
 * @param description A printf-style format string describing what kind of failure happened if
 *     @a status is not ok. Additional parameters are substituted into the placeholders in this
 *     format string.
 *
 * @return An NSError with its localizedDescription composed from the description format and its
 *     localizedFailureReason composed from any error message embedded in @a status.
 */
+ (nullable NSError *)errorWithStatus:(leveldb::Status)status
                          description:(NSString *)description, ... NS_FORMAT_FUNCTION(2, 3);

/**
 * Converts the given @a status to an NSString describing the status condition, suitable for
 * logging or inclusion in an NSError.
 *
 * @param status The status of the preceding LevelDB operation.
 *
 * @return An NSString describing the status (even if the status was ok).
 */
+ (NSString *)descriptionOfStatus:(leveldb::Status)status;

/** The native db pointer, allocated during start. */
@property(nonatomic, assign, readonly) leveldb::DB *ptr;

@property(nonatomic, readonly) firebase::firestore::local::LevelDbTransaction *currentTransaction;

@property(nonatomic, readonly) const std::set<std::string> &users;

@end

NS_ASSUME_NONNULL_END
