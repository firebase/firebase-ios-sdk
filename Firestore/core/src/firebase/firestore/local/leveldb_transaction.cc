

#include "Firestore/core/include/firebase/firestore/local/leveldb_transaction.h"

#include <leveldb/write_batch.h>
#ifdef __OBJC__
#import <Protobuf/GPBProtocolBuffers.h>
#endif

#import "Firestore/Source/Util/FSTAssert.h"

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
}

#ifdef __OBJC__
void LevelDBTransaction::Put(const std::string& key, GPBMessage *message) {
  NSData *data = [message data];
  Slice value((const char *)data.bytes, data.length);
  mutations_[key] = value;
}
#endif

LevelDBTransaction::Iterator::Iterator(LevelDBTransaction* txn)
    : ldb_iter_(txn->db_->NewIterator(txn->readOptions_)),
      mutations_(&txn->mutations_),
      deletions_(&txn->deletions_),
      mutations_iter_(std::make_unique<Mutations::iterator>(txn->mutations_.begin())) {
}

void LevelDBTransaction::Iterator::Seek(const std::string& key) {
  ldb_iter_->Seek(key);
  for (; ldb_iter_->Valid() && deletions_->find(ldb_iter_->key().ToString()) != deletions_->end();
       ldb_iter_->Next()) {
  }
  mutations_iter_.reset();
  mutations_iter_ = std::make_unique<Mutations::iterator>(mutations_->begin());
  for (; (*mutations_iter_) != mutations_->end() && (*mutations_iter_)->first < key;
       ++(*mutations_iter_)) {
  }
}

bool LevelDBTransaction::Iterator::is_mutation() {
  if (*mutations_iter_ == mutations_->end()) {
    return false;
  } else if (!ldb_iter_->Valid()) {
    return true;
  } else {
    const std::string key1 = (*mutations_iter_)->first;
    const std::string key2 = ldb_iter_->key().ToString();
    return key1 <= key2;
  }
}

std::string LevelDBTransaction::Iterator::key() {
  FSTCAssert(this->Valid(), @"key() called on invalid iterator");
  if (is_mutation()) {
    return (*mutations_iter_)->first;
  } else {
    return ldb_iter_->key().ToString();
  }
}

Slice LevelDBTransaction::Iterator::value() {
  FSTCAssert(this->Valid(), @"value() called on invalid iterator");
  if (is_mutation()) {
    return (*mutations_iter_)->second;
  } else {
    return ldb_iter_->value();
  }
}

void LevelDBTransaction::Iterator::AdvanceLDB() {
  do {
    ldb_iter_->Next();
  } while (ldb_iter_->Valid() &&
           deletions_->find(ldb_iter_->key().ToString()) != deletions_->end());
}

void LevelDBTransaction::Iterator::Next() {
  FSTCAssert(this->Valid(), @"Next() called on invalid iterator");
  if (is_mutation()) {
    // A mutation might be shadowing leveldb. If so, advance both.
    if (ldb_iter_->Valid() && ldb_iter_->key() == (*mutations_iter_)->first) {
      AdvanceLDB();
    }
    ++(*mutations_iter_);
  } else {
    AdvanceLDB();
  }
}

bool LevelDBTransaction::Iterator::Valid() {
  return ldb_iter_->Valid() || *mutations_iter_ != mutations_->end();
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
  if (!status.ok()) {
    FSTCFail(@"Failed to commit transaction: %s", status.ToString().c_str());
  }
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
