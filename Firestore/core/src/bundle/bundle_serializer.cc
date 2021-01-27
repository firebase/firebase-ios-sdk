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

#include "Firestore/core/src/bundle/bundle_serializer.h"

#include "absl/strings/numbers.h"
#include "absl/time/time.h"

namespace firebase {
namespace firestore {
namespace bundle {

using absl::FromUnixSeconds;
using absl::Nanoseconds;
using absl::ParseTime;
using absl::RFC3339_full;
using absl::SimpleAtoi;
using absl::Time;
using absl::ToUnixSeconds;
using model::SnapshotVersion;
using nlohmann::json;
using util::ReadContext;

template <typename int_type>
int_type ToInt(ReadContext* context, const json& value) {
  if (value.is_string()) {
    const auto& s = value.get_ref<const std::string&>();
    int_type result;
    auto ok = SimpleAtoi<int_type>(s, &result);
    if (!ok) {
      context->Fail("Failed to parse into integer: " + s);
    }

    return result;
  }
  return value.get<int_type>();
}

json Parse(const std::string s) {
  return json::parse(s, /* callback */ nullptr, /* allow_exception */ false);
}

BundleMetadata BundleSerializer::DecodeBundleMetadata(
    ReadContext* context, const std::string& metadata_string) const {
  const json& metadata = Parse(metadata_string);

  if (metadata.is_discarded()) {
    context->Fail("Failed to parse string into json: " + metadata_string);
    return BundleMetadata();
  }
  if (!metadata.contains("id") || !metadata.contains("version") ||
      !metadata.contains("createTime") ||
      !metadata.contains("totalDocuments") ||
      !metadata.contains("totalBytes")) {
    context->Fail("One of the field in BundleMetadata cannot be found.");
    return BundleMetadata();
  }

  return BundleMetadata(
      metadata.at("id").get<std::string>(),
      metadata.at("version").get<uint32_t>(),
      DecodeSnapshotVersion(context, metadata.at("createTime")),
      metadata.at("totalDocuments").get<uint32_t>(),
      ToInt<uint64_t>(context, metadata.at("totalBytes")));
}

SnapshotVersion BundleSerializer::DecodeSnapshotVersion(
    ReadContext* context, const json& version) const {
  if (version.is_string()) {
    Time time;
    std::string err;
    bool ok = ParseTime(RFC3339_full, version.get_ref<const std::string&>(),
                        &time, &err);
    if (ok) {
      auto seconds = ToUnixSeconds(time);
      auto nanos = (time - FromUnixSeconds(seconds)) / Nanoseconds(1);
      return SnapshotVersion(Timestamp(seconds, nanos));
    } else {
      context->Fail("Parsing time stamp failed with error: " + err);
      return SnapshotVersion::None();
    }
  }

  if (!version.contains("seconds") || !version.contains("nanos")) {
    context->Fail("Missing seconds or nanos in snapshot version.");
    return SnapshotVersion::None();
  }

  auto seconds = ToInt<int64_t>(context, version.at("seconds"));
  return SnapshotVersion(
      Timestamp(seconds, version.at("nanos").get<int32_t>()));
}

}  // namespace bundle
}  // namespace firestore
}  // namespace firebase
