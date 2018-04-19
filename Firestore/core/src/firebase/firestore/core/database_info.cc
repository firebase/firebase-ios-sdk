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

#include "Firestore/core/src/firebase/firestore/core/database_info.h"

namespace firebase {
namespace firestore {
namespace core {

DatabaseInfo::DatabaseInfo(
    const firebase::firestore::model::DatabaseId& database_id,
    const absl::string_view persistence_key,
    const absl::string_view host,
    bool ssl_enabled)
    : database_id_(database_id),
      persistence_key_(persistence_key),
      host_(host),
      ssl_enabled_(ssl_enabled) {
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
