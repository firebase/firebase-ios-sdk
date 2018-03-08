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

#include "Firestore/core/src/firebase/firestore/local/leveldb_transaction.h"

#include <leveldb/write_batch.h>
#if __OBJC__
#import <Protobuf/GPBProtocolBuffers.h>
#endif

#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"

using leveldb::DB;
using leveldb::ReadOptions;
using leveldb::Slice;
using leveldb::Status;
using leveldb::WriteBatch;
using leveldb::WriteOptions;

namespace firebase {
namespace firestore {
namespace local {

LevelDBTransaction::LevelDBTransaction(std::shared_ptr<DB> db,
                                       const ReadOptions& readOptions,
                                       const WriteOptions& writeOptions)
    : db_(db), readOptions_(readOptions), writeOptions_(writeOptions) {
}

void LevelDBTransaction::Put(const std::string& key, const Slice& value) {
  mutations_[key] = value;
  deletions_.erase(key);
  version_++;
}

LevelDBTransaction::Iterator::Iterator(LevelDBTransaction* txn)
    : ldb_iter_(txn->db_->NewIterator(txn->readOptions_)),
      txn_(txn),
      last_version_(txn->version_),
      is_valid_(false), // Iterator doesn't really point to anything yet, so is invalid
      mutations_iter_(
          std::make_unique<Mutations::iterator>(txn->mutations_.begin())) {
}

void LevelDBTransaction::Iterator::UpdateCurrent() {
  bool mutation_is_valid = *mutations_iter_ != txn_->mutations_.end();
  is_valid_ = mutation_is_valid || ldb_iter_->Valid();

  if (is_valid_) {
    if (!mutation_is_valid) {
      is_mutation_ = false;
    } else if (!ldb_iter_->Valid()) {
      is_mutation_ = true;
    } else {
      // both are valid
      const std::string mutation_key = (*mutations_iter_)->first;
      const std::string ldb_key = ldb_iter_->key().ToString();
      is_mutation_ = mutation_key <= ldb_key;
    }
    if (is_mutation_) {
      current_.first = (*mutations_iter_)->first;
      current_.second = (*mutations_iter_)->second;
    } else {
      current_.first = ldb_iter_->key().ToString();
      current_.second = ldb_iter_->value();
    }
  }
}

void LevelDBTransaction::Iterator::Seek(const std::string& key) {
  ldb_iter_->Seek(key);
  for (; ldb_iter_->Valid() &&
         txn_->deletions_.find(ldb_iter_->key().ToString()) != txn_->deletions_.end();
       ldb_iter_->Next()) {
  }
  mutations_iter_.reset();
  mutations_iter_ = std::make_unique<Mutations::iterator>(txn_->mutations_.begin());
  for (; (*mutations_iter_) != txn_->mutations_.end() &&
         (*mutations_iter_)->first < key;
       ++(*mutations_iter_)) {
  }
  UpdateCurrent();
  last_version_ = txn_->version_;
}

std::string LevelDBTransaction::Iterator::key() {
  FIREBASE_ASSERT_MESSAGE(Valid(), "key() called on invalid iterator");
  return current_.first;
}

Slice LevelDBTransaction::Iterator::value() {
  FIREBASE_ASSERT_MESSAGE(Valid(), "value() called on invalid iterator");
  return current_.second;
}

bool LevelDBTransaction::Iterator::SyncToTransaction() {
  if (last_version_ < txn_->version_) {
    std::string current_key = current_.first;
    Seek(current_key);
    // If we advanced, we don't need to advance again.
    return is_valid_  && current_.first > current_key;
  } else {
    return false;
  }
}

void LevelDBTransaction::Iterator::AdvanceLDB() {
  do {
    ldb_iter_->Next();
  } while (ldb_iter_->Valid() &&
           txn_->deletions_.find(ldb_iter_->key().ToString()) != txn_->deletions_.end());
}

void LevelDBTransaction::Iterator::Next() {
  FIREBASE_ASSERT_MESSAGE(Valid(), "Next() called on invalid iterator");
  bool advanced = SyncToTransaction();
  if (!advanced) {
    if (is_mutation_) {
      // A mutation might be shadowing leveldb. If so, advance both.
      if (ldb_iter_->Valid() && ldb_iter_->key() == (*mutations_iter_)->first) {
        AdvanceLDB();
      }
      ++(*mutations_iter_);
    } else {
      AdvanceLDB();
    }
    UpdateCurrent();
  }
}

bool LevelDBTransaction::Iterator::Valid() {
  return is_valid_;
}

LevelDBTransaction::Iterator* LevelDBTransaction::NewIterator() {
  return new LevelDBTransaction::Iterator(this);
}

Status LevelDBTransaction::Get(const std::string& key, std::string* value) {
  Iterator iter(this);
  iter.Seek(key);
  if (iter.Valid() && iter.key() == key) {
    *value = iter.value().ToString();
    return Status::OK();
  } else {
    return Status::NotFound(key + " is not present in the transaction");
  }
}

void LevelDBTransaction::Delete(const std::string& key) {
  deletions_.insert(key);
  mutations_.erase(key);
  version_++;
}

void LevelDBTransaction::Commit() {
  WriteBatch toWrite;
  for (auto it = deletions_.begin(); it != deletions_.end(); it++) {
    toWrite.Delete(*it);
  }

  for (auto it = mutations_.begin(); it != mutations_.end(); it++) {
    toWrite.Put(it->first, it->second);
  }

  Status status = db_->Write(writeOptions_, &toWrite);
  FIREBASE_ASSERT_MESSAGE(status.ok(), "Failed to commit transaction: %s",
                          status.ToString().c_str());
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
