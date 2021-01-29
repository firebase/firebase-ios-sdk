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
namespace {

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
int_type ToInt(ReadContext& context, const json& value) {
  if (value.is_number_integer()) {
    return value.get<int_type>();
  }

  int_type result = 0;
  if (value.is_string()) {
    const auto& s = value.get_ref<const std::string&>();
    auto ok = SimpleAtoi<int_type>(s, &result);
    if (!ok) {
      context.Fail("Failed to parse into integer: " + s);
    }

    return result;
  }

  context.Fail(
      "Trying to parse a json value that is neither a string nor an integer "
      "number into an integer");
  return result;
}

std::string ToString(ReadContext& context, const json& value) {
  if (value.is_string()) {
    return value.get<std::string>();
  }

  context.Fail(
      "Trying to parse a json value that is not a string into a string");
  return std::string();
}

json Parse(const std::string& s) {
  return json::parse(s, /*callback=*/nullptr, /*allow_exception=*/false);
}

}  // namespace

BundleMetadata BundleSerializer::DecodeBundleMetadata(
    ReadContext& context, const std::string& metadata_string) const {
  const json& metadata = Parse(metadata_string);

  if (metadata.is_discarded()) {
    context.Fail("Failed to parse string into json: " + metadata_string);
    return BundleMetadata();
  }
  if (!metadata.contains("id") || !metadata.contains("version") ||
      !metadata.contains("createTime") ||
      !metadata.contains("totalDocuments") ||
      !metadata.contains("totalBytes")) {
    context.Fail("One of the field in BundleMetadata cannot be found.");
    return BundleMetadata();
  }

  return BundleMetadata(
      ToString(context, metadata.at("id")),
      ToInt<uint32_t>(context, metadata.at("version")),
      DecodeSnapshotVersion(context, metadata.at("createTime")),
      ToInt<uint32_t>(context, metadata.at("totalDocuments")),
      ToInt<uint64_t>(context, metadata.at("totalBytes")));
}

SnapshotVersion BundleSerializer::DecodeSnapshotVersion(
    ReadContext& context, const json& version) const {
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
      context.Fail("Parsing timestamp failed with error: " + err);
      return SnapshotVersion::None();
    }
  }

  if (!version.contains("seconds") || !version.contains("nanos")) {
    context.Fail("Missing seconds or nanos in snapshot version.");
    return SnapshotVersion::None();
  }

  return SnapshotVersion(
      Timestamp(ToInt<int64_t>(context, version.at("seconds")),
                ToInt<int32_t>(context, version.at("nanos"))));
}

}  // namespace bundle
}  // namespace firestore
}  // namespace firebase
