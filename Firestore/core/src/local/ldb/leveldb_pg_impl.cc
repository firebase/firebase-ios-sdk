/*
 * Copyright 2022 Google
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

#include <memory>
#include <optional>
#include <string>
#include <tuple>
#include <utility>

#include "Firestore/core/src/local/ldb/leveldb_interface.h"
#include "Firestore/core/src/util/async_queue.h"
#include "Firestore/core/src/util/executor.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/log.h"
#include "absl/strings/string_view.h"

#include <pqxx/pqxx>
#include <variant>

namespace firebase {
namespace firestore {
namespace local {
namespace ldb {

#ifdef PG_PERSISTENCE
namespace {
void DoPut(pqxx::nontransaction& txn, const Slice& key, const Slice& value) {
  txn.exec_params(
      "insert into firestore_cache (key, value) values ($1, $2) ON CONFLICT "
      "(key) DO UPDATE set value = $2",
      pqxx::binarystring(key.ToString()), pqxx::binarystring(value.ToString()));
}

void DoDelete(pqxx::nontransaction& txn, const Slice& key) {
  txn.exec_params("delete from firestore_cache where key = $1",
                  pqxx::binarystring(key.ToString()));
}
}  // namespace

const char* Status::CopyState(const char* state) {
  uint32_t size;
  memcpy(&size, state, sizeof(size));
  char* result = new char[size + 5];
  memcpy(result, state, size + 5);
  return result;
}

Status::Status(Code code, const Slice& msg, const Slice& msg2) {
  assert(code != kOk);
  const uint32_t len1 = msg.size();
  const uint32_t len2 = msg2.size();
  const uint32_t size = len1 + (len2 ? (2 + len2) : 0);
  char* result = new char[size + 5];
  memcpy(result, &size, sizeof(size));
  result[4] = static_cast<char>(code);
  memcpy(result + 5, msg.data(), len1);
  if (len2) {
    result[5 + len1] = ':';
    result[6 + len1] = ' ';
    memcpy(result + 7 + len1, msg2.data(), len2);
  }
  state_ = result;
}

std::string Status::ToString() const {
  if (state_ == nullptr) {
    return "OK";
  } else {
    char tmp[30];
    const char* type;
    switch (code()) {
      case kOk:
        type = "OK";
        break;
      case kNotFound:
        type = "NotFound: ";
        break;
      case kCorruption:
        type = "Corruption: ";
        break;
      case kNotSupported:
        type = "Not implemented: ";
        break;
      case kInvalidArgument:
        type = "Invalid argument: ";
        break;
      case kIOError:
        type = "IO error: ";
        break;
      default:
        snprintf(tmp, sizeof(tmp),
                 "Unknown code(%d): ", static_cast<int>(code()));
        type = tmp;
        break;
    }
    std::string result(type);
    uint32_t length;
    memcpy(&length, state_, sizeof(length));
    result.append(state_ + 5, length);
    return result;
  }
}

// Store the mapping "key->value" in the database.
void WriteBatch::Put(const Slice& key, const Slice& value) {
  operations_.push_back(std::make_tuple(key, value));
}

// If the database contains a mapping for "key", erase it.  Else do nothing.
void WriteBatch::Delete(const Slice& key) {
  operations_.push_back(key);
}

DB::DB() : conn_(pqxx::connection()) {
  txn_ = std::make_unique<pqxx::nontransaction>(conn_);
  async_queue_ =
      util::AsyncQueue::Create(util::Executor::CreateSerial("ldb_pg"));
}

DB::DB(pqxx::connection conn) : conn_(std::move(conn)) {
  txn_ = std::make_unique<pqxx::nontransaction>(conn_);
  async_queue_ =
      util::AsyncQueue::Create(util::Executor::CreateSerial("ldb_pg"));
}

Status DB::Open(const Options& options, const std::string& name, DB** dbptr) {
  (void)options;
  (void)name;

  DB* db = new DB(pqxx::connection("postgresql://localhost/leveldb"));
  LOG_DEBUG("Connecting to ", db->conn_.connection_string());
  db->txn_->exec(
      "CREATE TABLE IF NOT EXISTS firestore_cache (key bytea, value bytea, "
      "PRIMARY KEY(key))");

  *dbptr = db;

  return Status::OK();
}

Status DB::Put(const WriteOptions& options,
               const Slice& key,
               const Slice& value) {
  (void)options;
  async_queue_->EnqueueBlocking(
      [this, key, value]() { DoPut(*txn_, key, value); });

  return Status::OK();
}

Status DB::Delete(const WriteOptions& options, const Slice& key) {
  (void)options;
  async_queue_->EnqueueBlocking([this, key]() { DoDelete(*txn_, key); });

  return Status::OK();
}

Status DB::DropCache() {
  async_queue_->EnqueueBlocking(
      [this]() { txn_->exec_params("DELETE from firestore_cache"); });
  return Status::OK();
}

Status DB::Write(const WriteOptions& options, WriteBatch* updates) {
  (void)options;
  LOG_WARN("Writing batch...");
  async_queue_->EnqueueBlocking([this, updates]() {
    for (const auto& op : updates->oprations()) {
      const auto* delete_key = std::get_if<Slice>(&op);
      if (delete_key != nullptr) {
        DoDelete(*txn_, *delete_key);
      } else {
        const auto* update = std::get_if<std::tuple<Slice, Slice>>(&op);
        DoPut(*txn_, std::get<0>(*update), std::get<1>(*update));
      }
    }
  });
  LOG_WARN("Done writing batch...");
  return Status::OK();
}

Status DB::Get(const ReadOptions& options,
               const Slice& key,
               std::string* value) {
  (void)options;
  LOG_WARN("Running get for key ", key.ToString());
  std::optional<std::tuple<pqxx::binarystring>> result;
  async_queue_->EnqueueBlocking([this, key, &result]() {
    result = txn_->query01<pqxx::binarystring>(
        "select value from firestore_cache where key = " +
        txn_->quote_raw(key.ToString()));
    LOG_WARN("Done running get for key ", key.ToString());
  });

  if (result.has_value()) {
    LOG_WARN("Get one");
    *value = std::get<0>(result.value()).view();
    return Status::OK();
  } else {
    return Status::NotFound("No value is found for key " + key.ToString());
  }
}

Iterator::Iterator(pqxx::nontransaction* txn,
                   std::shared_ptr<util::AsyncQueue> queue)
    : txn_(txn), queue_(queue) {
}

bool Iterator::Valid() const {
  return valid_;
}

void Iterator::SeekToLast() {
  queue_->EnqueueBlocking([this]() {
    auto result = txn_->query01<pqxx::binarystring, pqxx::binarystring>(
        "select key, value from firestore_cache order by key DESC limit 1");

    if (result.has_value()) {
      valid_ = true;
      key_ = std::get<0>(result.value()).str();
      value_ = std::get<1>(result.value()).str();
    } else {
      valid_ = false;
      key_ = "";
      value_ = "";
    }
  });
}

// Position at the first key in the source that is at or past target.
// The iterator is Valid() after this call iff the source contains
// an entry that comes at or past target.
void Iterator::Seek(const Slice& target) {
  LOG_WARN("Seeking..");
  queue_->EnqueueBlocking([this, target]() {
    auto result = txn_->query01<pqxx::binarystring, pqxx::binarystring>(
        "select key, value from firestore_cache where key >= " +
        txn_->quote_raw(target.ToString()) + " order by key limit 1");
    LOG_WARN("Done seeking..");

    if (result.has_value()) {
      valid_ = true;
      key_ = std::get<0>(result.value()).str();
      value_ = std::get<1>(result.value()).str();
    } else {
      valid_ = false;
      key_ = "";
      value_ = "";
    }
  });
}

// REQUIRES: Valid()
void Iterator::Next() {
  HARD_ASSERT(valid_, "Next() expect iterator to be valid");
  queue_->EnqueueBlocking([this]() {
    auto result = txn_->query01<pqxx::binarystring, pqxx::binarystring>(
        "select key, value from firestore_cache where key > " +
        txn_->quote_raw(key_) + " order by key limit 1");

    if (result.has_value()) {
      valid_ = true;
      key_ = std::get<0>(result.value()).str();
      value_ = std::get<1>(result.value()).str();
    } else {
      valid_ = false;
      key_ = "";
      value_ = "";
    }
  });
}

// REQUIRES: Valid()
void Iterator::Prev() {
  HARD_ASSERT(valid_, "Prev() expect iterator to be valid");

  queue_->EnqueueBlocking([this]() {
    auto result = txn_->query01<pqxx::binarystring, pqxx::binarystring>(
        "select key, value from firestore_cache where key < " +
        txn_->quote_raw(key_) + " order by key DESC limit 1");

    if (result.has_value()) {
      valid_ = true;
      key_ = std::get<0>(result.value()).str();
      value_ = std::get<1>(result.value()).str();
    } else {
      valid_ = false;
      key_ = "";
      value_ = "";
    }
  });
}

// REQUIRES: Valid()
Slice Iterator::key() {
  return key_;
}

// REQUIRES: Valid()
Slice Iterator::value() {
  return value_;
}

// If an error has occurred, return it.  Else return an ok status.
Status Iterator::status() {
  return Status::OK();
}

Iterator* DB::NewIterator(const ReadOptions& options) {
  (void)options;
  return new Iterator(txn_.get(), async_queue_);
}

#endif
}  // namespace ldb
}  // namespace local
}  // namespace firestore
}  // namespace firebase
