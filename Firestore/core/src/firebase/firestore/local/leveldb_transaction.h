/*
 * Copyright 2018 Google
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

#ifndef FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_LOCAL_LEVELDB_TRANSACTION_H_
#define FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_LOCAL_LEVELDB_TRANSACTION_H_

#include <leveldb/db.h>
#include <map>
#include <set>

#if __OBJC__
#if !defined(GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS)
#define GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS 0
#endif

#if GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS
#import <Protobuf/GPBProtocolBuffers.h>
#else
#import "GPBProtocolBuffers.h"
#endif
#endif

namespace firebase {
namespace firestore {
namespace local {

typedef std::map<std::string, std::string> Mutations;
typedef std::set<std::string> Deletions;

/**
 * LevelDBTransaction tracks pending changes to entries in leveldb, including
 * deletions. It also provides an Iterator to traverse a merged view of pending
 * changes and committed values.
 */
class LevelDBTransaction {
 public:
  LevelDBTransaction(std::shared_ptr<leveldb::DB> db,
                     const leveldb::ReadOptions& readOptions,
                     const leveldb::WriteOptions& writeOptions);

  LevelDBTransaction(const LevelDBTransaction& other) = delete;

  LevelDBTransaction& operator=(const LevelDBTransaction& other) = delete;

  void Delete(const std::string& key);

#if __OBJC__
  void Put(const std::string& key, GPBMessage* message) {
    NSData* data = [message data];
    mutations_[key] = std::string((const char*)data.bytes, data.length);
    version_++;
  }
#endif

  void Put(const std::string& key, const std::string& value);

  leveldb::Status Get(const std::string& key, std::string* value);

  /**
   * Iterator iterates over a merged view of pending changes from the
   * transaction and any unchanged values in the underlying leveldb instance.
   */
  class Iterator {
   public:
    explicit Iterator(LevelDBTransaction* txn);

    Iterator& operator=(const Iterator& other) = delete;

    /**
     * Seeks this iterator to the first key equal to or greater than the given
     * key
     */
    void Seek(const std::string& key);

    /**
     * Returns true if this iterator points to an entry
     */
    bool Valid();

    /**
     * Advances the iterator to the next entry
     */
    void Next();

    /**
     * Returns the key of the current entry
     */
    std::string key();

    bool key_starts_with(const std::string& prefix);

    /**
     * Returns the value of the current entry
     */
    leveldb::Slice value();

   private:
    std::unique_ptr<leveldb::Iterator> ldb_iter_;

    // The last observed version of the underlying transaction
    unsigned int last_version_;
    // The underlying transaction.
    LevelDBTransaction* txn_;
    std::unique_ptr<Mutations::iterator> mutations_iter_;
    // We save the current key and value so that once an iterator is Valid(), it
    // remains so at least until the next call to Seek() or Next(), even if the
    // underlying data is deleted.
    std::pair<std::string, std::string> current_;
    // True if current_ represents a mutation, rather than committed data.
    bool is_mutation_;
    // True if the iterator pointed to a valid entry the last time Next() or
    // Seek() was called.
    bool is_valid_;

    /**
     * Advances to the next non-deleted key in leveldb.
     */
    void AdvanceLDB();

    /**
     * Syncs with the underlying transaction. If the transaction has been
     * updated, the mutation iterator may need to be reset.
     */
    bool SyncToTransaction();

    /**
     * Given the current state of the internal iterators, set is_valid_,
     * is_mutation_, and current_.
     */
    void UpdateCurrent();
  };

  /**
   * Returns a new Iterator over the pending changes in this transaction, merged
   * with the existing values already in leveldb.
   */
  Iterator* NewIterator();

  /**
   * Commits the transaction. All pending changes are written. The transaction
   * should not be used after calling this method.
   */
  void Commit();

 private:
  std::shared_ptr<leveldb::DB> db_;
  Mutations mutations_;
  Deletions deletions_;
  leveldb::WriteOptions writeOptions_;
  leveldb::ReadOptions readOptions_;
  unsigned int version_ = 0;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_LOCAL_LEVELDB_TRANSACTION_H_
