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

#ifndef FIRESTORE_CORE_SRC_LOCAL_LDB_LEVELDB_INTERFACE_H_
#define FIRESTORE_CORE_SRC_LOCAL_LDB_LEVELDB_INTERFACE_H_

#include <string>
#include <utility>

#include "absl/strings/string_view.h"
#include "leveldb/db.h"
#include "leveldb/options.h"
#include "leveldb/slice.h"
#include "leveldb/write_batch.h"

#include <pqxx/pqxx>

namespace firebase {
namespace firestore {
namespace local {
namespace ldb {

using DB = ::leveldb::DB;
using Slice = ::leveldb::Slice;
using Iterator = ::leveldb::Iterator;
using Options = ::leveldb::Options;
using ReadOptions = ::leveldb::ReadOptions;
using WriteOptions = ::leveldb::WriteOptions;
using WriteBatch = ::leveldb::WriteBatch;
using Status = ::leveldb::Status;

void test() {
  auto conn = pqxx::connection();
  conn.close();
}

}  // namespace ldb
}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif // FIRESTORE_CORE_SRC_LOCAL_LDB_LEVELDB_INTERFACE_H_
