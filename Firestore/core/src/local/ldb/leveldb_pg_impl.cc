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

#include <optional>
#include <string>
#include <tuple>
#include <utility>

#include "Firestore/core/src/local/ldb/leveldb_interface.h"
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
void DoPut(pqxx::work& txn, const Slice& key, const Slice& value) {
  txn.exec_params(
      "insert into firestore_cache (key, value) values ($1, $2) ON CONFLICT "
      "(key) DO UPDATE set value = $2",
      key.ToString(), value.ToString());
}

void DoDelete(pqxx::work& txn, const Slice& key) {
  txn.exec_params("delete from firestore_cache where key = $1", key.ToString());
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
}

DB::DB(pqxx::connection conn) : conn_(std::move(conn)) {
}

Status DB::Open(const Options& options, const std::string& name, DB** dbptr) {
  (void)options;
  (void)name;

  DB* db = new DB(pqxx::connection("postgresql://localhost/leveldb"));
  LOG_DEBUG("Connecting to ", db->conn_.connection_string());
  pqxx::work txn{db->conn_};
  txn.exec(
      "CREATE TABLE IF NOT EXISTS firestore_cache (key text, value text);");
  txn.commit();

  *dbptr = db;

  return Status::OK();
}

Status DB::Put(const WriteOptions& options,
               const Slice& key,
               const Slice& value) {
  (void)options;
  pqxx::work txn(conn_);
  DoPut(txn, key, value);
  txn.commit();

  return Status::OK();
}

Status DB::Delete(const WriteOptions& options, const Slice& key) {
  (void)options;
  pqxx::work txn(conn_);
  DoDelete(txn, key);
  txn.commit();

  return Status::OK();
}

Status DB::Write(const WriteOptions& options, WriteBatch* updates) {
  (void)options;
  pqxx::work txn(conn_);

  for (const auto& op : updates->oprations()) {
    const auto* delete_key = std::get_if<Slice>(&op);
    if (delete_key != nullptr) {
      DoDelete(txn, *delete_key);
    } else {
      const auto* update = std::get_if<std::tuple<Slice, Slice>>(&op);
      DoPut(txn, std::get<0>(*update), std::get<1>(*update));
    }
  }

  txn.commit();

  return Status::OK();
}

Status DB::Get(const ReadOptions& options,
               const Slice& key,
               std::string* value) {
  (void)options;
  pqxx::work txn(conn_);
  std::optional<std::tuple<std::string>> result = txn.query01<std::string>(
      "select value from firestore_cache where key = " +
      txn.quote(key.ToString()));
  txn.commit();

  if (result.has_value()) {
    *value = std::get<0>(result.value());
    return Status::OK();
  } else {
    return Status::NotFound("No value is found for key " + key.ToString());
  }
}

bool Iterator::Valid() const {
  return valid_;
}

void Iterator::SeekToLast() {
}

void Iterator::Seek(const Slice& target) {
  (void)target;
}

// REQUIRES: Valid()
void Iterator::Next() {
}

// REQUIRES: Valid()
void Iterator::Prev() {
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
  if (valid_) {
    return Status::OK();
  }

  return Status::InvalidArgument("Invalid iterator position.");
}

Iterator* DB::NewIterator(const ReadOptions& options) {
  (void)options;
  return new Iterator();
}

#endif
}  // namespace ldb
}  // namespace local
}  // namespace firestore
}  // namespace firebase
