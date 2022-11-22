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

#include <string>
#include <utility>

#include "Firestore/core/src/local/ldb/leveldb_interface.h"
#include "Firestore/core/src/util/log.h"
#include "absl/strings/string_view.h"

#include <pqxx/pqxx>

namespace firebase {
namespace firestore {
namespace local {
namespace ldb {

#ifdef PG_PERSISTENCE

DB::DB(): conn_(pqxx::connection()) {
}

DB::DB(pqxx::connection conn): conn_(std::move(conn)) {
}

Status DB::Open(const Options& options, const std::string& name, DB** dbptr) {
  (void)options;
  (void)name;

  DB* db = new DB(pqxx::connection("postgresql://localhost/leveldb"));
  LOG_DEBUG("Connecting to ", db->conn_.connection_string());
  *dbptr = db;

  return Status::OK();
}

#endif
}  // namespace ldb
}  // namespace local
}  // namespace firestore
}  // namespace firebase
