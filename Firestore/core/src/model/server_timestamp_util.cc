/*
 * Copyright 2021 Google LLC
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

#include "Firestore/core/src/model/server_timestamp_util.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {
namespace model {

const char kTypeKey[] = "__type__";
const char kLocalWriteTimeKey[] = "__local_write_time__";
const char kServerTimestampSentinel[] = "server_timestamp";

bool IsServerTimestamp(const google_firestore_v1_Value& value) {
  if (value.which_value_type != google_firestore_v1_Value_map_value_tag) {
    return false;
  }

  if (value.map_value.fields_count > 3) {
    return false;
  }

  for (size_t i = 0; i < value.map_value.fields_count; ++i) {
    const auto& field = value.map_value.fields[i];
    absl::string_view key = nanopb::MakeStringView(field.key);
    if (key == kTypeKey) {
      return field.value.which_value_type ==
                 google_firestore_v1_Value_string_value_tag &&
             nanopb::MakeStringView(field.value.string_value) ==
                 kServerTimestampSentinel;
    }
  }

  return false;
}

const google_firestore_v1_Value& GetLocalWriteTime(
    const firebase::firestore::google_firestore_v1_Value& value) {
  for (size_t i = 0; i < value.map_value.fields_count; ++i) {
    const auto& field = value.map_value.fields[i];
    absl::string_view key = nanopb::MakeStringView(field.key);
    if (key == kLocalWriteTimeKey) {
      return field.value;
    }
  }

  HARD_FAIL("LocalWriteTime not found");
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
