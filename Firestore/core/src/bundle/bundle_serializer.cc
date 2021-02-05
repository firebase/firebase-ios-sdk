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

#include <memory>
#include <vector>

#include "Firestore/core/src/core/bound.h"
#include "Firestore/core/src/core/direction.h"
#include "Firestore/core/src/core/field_filter.h"
#include "Firestore/core/src/core/filter.h"
#include "Firestore/core/src/core/order_by.h"
#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/core/target.h"
#include "Firestore/core/src/model/document.h"
#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/src/model/field_value.h"
#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/src/nanopb/byte_string.h"
#include "Firestore/core/src/nanopb/reader.h"
#include "Firestore/core/src/util/statusor.h"
#include "absl/strings/escaping.h"
#include "absl/strings/numbers.h"
#include "absl/time/time.h"

namespace firebase {
namespace firestore {
namespace bundle {
namespace {

using absl::Base64Unescape;
using absl::FromUnixSeconds;
using absl::Nanoseconds;
using absl::ParseTime;
using absl::RFC3339_full;
using absl::SimpleAtod;
using absl::SimpleAtoi;
using absl::Time;
using absl::ToUnixSeconds;
using core::Bound;
using core::Direction;
using core::FieldFilter;
using core::Filter;
using core::FilterList;
using core::LimitType;
using core::OrderBy;
using core::OrderByList;
using core::Query;
using core::Target;
using immutable::AppendOnlyList;
using model::Document;
using model::DocumentKey;
using model::FieldPath;
using model::FieldValue;
using model::ObjectValue;
using model::ResourcePath;
using model::SnapshotVersion;
using nanopb::ByteString;
using nanopb::Reader;
using nlohmann::json;
using util::ReadContext;
using util::StatusOr;

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

double ToDouble(ReadContext& context, const json& value) {
  if (value.is_number()) {
    return value.get<double>();
  }

  double result = 0;
  if (value.is_string()) {
    const auto& s = value.get_ref<const std::string&>();
    auto ok = SimpleAtod(s, &result);
    if (!ok) {
      context.Fail("Failed to parse into double: " + s);
    }

    return result;
  }

  context.Fail(
      "Trying to parse a json value that is neither a string nor an double "
      "number into an double result");
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

Timestamp DecodeTimestamp(ReadContext& context, const json& version) {
  if (version.is_string()) {
    Time time;
    std::string err;
    bool ok = ParseTime(RFC3339_full, version.get_ref<const std::string&>(),
                        &time, &err);
    if (ok) {
      auto seconds = ToUnixSeconds(time);
      auto nanos = (time - FromUnixSeconds(seconds)) / Nanoseconds(1);
      return Timestamp(seconds, nanos);
    } else {
      context.Fail("Parsing timestamp failed with error: " + err);
      return Timestamp();
    }
  }

  if (!version.contains("seconds") || !version.contains("nanos")) {
    context.Fail("Missing seconds or nanos in snapshot version.");
    return Timestamp();
  }

  return Timestamp(ToInt<int64_t>(context, version.at("seconds")),
                   ToInt<int32_t>(context, version.at("nanos")));
}

SnapshotVersion DecodeSnapshotVersion(ReadContext& context,
                                      const json& version) {
  auto timestamp = DecodeTimestamp(context, version);
  if (!context.ok()) {
    return SnapshotVersion::None();
  }

  return SnapshotVersion(std::move(timestamp));
}

void VerifyStructuredQuery(ReadContext& context, const json& query) {
  if (!query.is_object()) {
    context.Fail("'structuredQuery' is not an object as expected.");
    return;
  }
  if (query.contains("select")) {
    context.Fail(
        "Queries with 'select' statements are not supported by the SDK");
    return;
  }
  if (!query.contains("from")) {
    context.Fail("Query does not have a 'from' collection");
    return;
  }
  if (query.contains("offset")) {
    context.Fail("Queries with 'offset' are not supported by the SDK");
    return;
  }
}

void DecodeCollectionSource(ReadContext& context,
                            ResourcePath& parent,
                            std::string& group,
                            const json& from_json) {
  const auto& from = from_json.get_ref<const std::vector<json>&>();
  if (from.size() != 1) {
    context.Fail(
        "Only queries with a single 'from' clause are supported by the SDK");
    return;
  }
  const auto& collection_selector = from.at(0);
  if (!collection_selector.contains("collectionId") ||
      !collection_selector.at("collectionId").is_string()) {
    context.Fail("Collection ID is missing from the query or is not a string");
    return;
  }

  bool all_descendants =
      collection_selector.contains("allDescendants") &&
      collection_selector.at("allDescendants").is_boolean() &&
      collection_selector.at("allDescendants").get<bool>();
  if (all_descendants) {
    group = collection_selector.at("collectionId").get<std::string>();
  } else {
    parent = parent.Append(
        collection_selector.at("collectionId").get_ref<const std::string&>());
  }
}

FieldPath DecodeFieldReference(ReadContext& context, const json& field) {
  if (!field.is_object() || !field.contains("fieldPath")) {
    context.Fail("");
    return FieldPath();
  }

  auto result =
      FieldPath::FromServerFormat(ToString(context, field.at("fieldPath")));
  if (!result.ok()) {
    context.set_status(result.status());
    return FieldPath();
  } else {
    return result.ConsumeValueOrDie();
  }
}

Filter::Operator DecodeFieldFilterOperator(ReadContext& context,
                                           const json& op) {
  if (!op.is_string()) {
    context.Fail("Operator in filter is not a string");
    // We have to return something.
    return Filter::Operator::Equal;
  }
  const auto& s = op.get_ref<const std::string&>();
  if (s == "LESS_THAN") {
    return Filter::Operator::LessThan;
  } else if (s == "LESS_THAN_OR_EQUAL") {
    return Filter::Operator::LessThanOrEqual;
  } else if (s == "EQUAL") {
    return Filter::Operator::Equal;
  } else if (s == "NOT_EQUAL") {
    return Filter::Operator::NotEqual;
  } else if (s == "GREATER_THAN") {
    return Filter::Operator::GreaterThan;
  } else if (s == "GREATER_THAN_OR_EQUAL") {
    return Filter::Operator::GreaterThanOrEqual;
  } else if (s == "ARRAY_CONTAINS") {
    return Filter::Operator::ArrayContains;
  } else if (s == "IN") {
    return Filter::Operator::In;
  } else if (s == "ARRAY_CONTAINS_ANY") {
    return Filter::Operator::ArrayContainsAny;
  } else if (s == "NOT_IN") {
    return Filter::Operator::NotIn;
  } else {
    context.Fail("Operator in filter is not valid: " + s);
    // We have to return something.
    return Filter::Operator::Equal;
  }
}

void DecodeUnaryFilter(ReadContext& context,
                       FilterList& result,
                       const json& filter) {
  if (!filter.contains("field") || !filter.contains("op")) {
    context.Fail(
        "One of the 'field' or 'op' fields is missing from unary filter");
    return;
  }

  FieldPath path = DecodeFieldReference(context, filter.at("field"));
  if (!context.ok()) {
    return;
  }

  std::string op = ToString(context, filter.at("op"));
  if (!context.ok()) {
    return;
  }

  if (op == "IS_NAN") {
    result = result.push_back(FieldFilter::Create(
        std::move(path), Filter::Operator::Equal, FieldValue::Nan()));
  } else if (op == "IS_NULL") {
    result = result.push_back(FieldFilter::Create(
        std::move(path), Filter::Operator::Equal, FieldValue::Null()));
  } else if (op == "IS_NOT_NAN") {
    result = result.push_back(FieldFilter::Create(
        std::move(path), Filter::Operator::NotEqual, FieldValue::Nan()));
  } else if (op == "IS_NOT_NULL") {
    result = result.push_back(FieldFilter::Create(
        std::move(path), Filter::Operator::NotEqual, FieldValue::Null()));
  } else {
    context.Fail("Unexpected unary filter operator: " + op);
  }
}

OrderByList DecodeOrderBy(ReadContext& context, const json& query) {
  if (!query.contains("orderBy")) {
    return OrderByList();
  }

  const auto& order_bys = query.at("orderBy");
  if (!order_bys.is_array()) {
    context.Fail("Query's 'orderBy' clause is not a json array.");
    return OrderByList();
  }

  OrderByList result;
  for (const auto& order_by : order_bys.get_ref<const std::vector<json>&>()) {
    if (!order_by.contains("field")) {
      context.Fail("'orderBy' clause has no field specified");
      return OrderByList();
    }

    FieldPath path = DecodeFieldReference(context, order_by.at("field"));
    if (!context.ok()) {
      return OrderByList();
    }

    std::string direction_string = "ASCENDING";
    if (order_by.contains("direction") &&
        order_by.at("direction").is_string()) {
      direction_string = ToString(context, order_by.at("direction"));
      if (!context.ok()) {
        return OrderByList();
      }
    }
    if (direction_string != "DESCENDING" && direction_string != "ASCENDING") {
      context.Fail("'direction' value is invalid: " + direction_string);
      return OrderByList();
    }

    Direction direction = direction_string == "ASCENDING"
                              ? Direction::Ascending
                              : Direction::Descending;

    result = result.push_back(OrderBy(std::move(path), direction));
  }

  return result;
}

int32_t DecodeLimit(ReadContext& context, const json& query) {
  int32_t limit = Target::kNoLimit;
  if (query.contains("limit")) {
    if (!query.at("limit").is_number_integer()) {
      context.Fail("'limit' is not encoded as a valid integer");
      return limit;
    }
    limit = query.at("limit").get<int32_t>();
  }

  return limit;
}

LimitType DecodeLimitType(ReadContext& context, const json& query) {
  std::string limit_type = "FIRST";
  if (query.contains("limitType")) {
    if (!query.at("limitType").is_string()) {
      context.Fail("'limitType' is not encoded as a string");
      return LimitType::None;
    }

    limit_type = query.at("limitType").get_ref<const std::string&>();
  }

  if (limit_type == "FIRST") {
    return LimitType::First;
  } else if (limit_type == "LAST") {
    return LimitType::Last;
  } else {
    context.Fail("'limitType' is not encoded as a recognizable value");
    return LimitType::None;
  }
}

FieldValue DecodeGeoPointValue(ReadContext& context, const json& geo_json) {
  double latitude = 0;
  if (geo_json.contains("latitude")) {
    if (!geo_json.at("latitude").is_number()) {
      context.Fail("Geo Point's 'latitude' is not encoded as a number");
      return FieldValue();
    }
    latitude = geo_json.at("latitude").get<double>();
  }

  double longitude = 0;
  if (geo_json.contains("longitude")) {
    if (!geo_json.at("longitude").is_number()) {
      context.Fail("Geo Point's 'longitude' is not encoded as a number");
      return FieldValue();
    }
    longitude = geo_json.at("longitude").get<double>();
  }
  return FieldValue::FromGeoPoint(GeoPoint(latitude, longitude));
}

FieldValue DecodeBytesValue(ReadContext& context, const json& bytes_json) {
  auto val = ToString(context, bytes_json);
  if (!context.ok()) {
    return FieldValue();
  }

  std::string decoded;
  if (!Base64Unescape(val, &decoded)) {
    context.Fail("Failed to decode bytesValue string into binary form");
    return FieldValue();
  }
  return FieldValue::FromBlob(ByteString((decoded)));
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

NamedQuery BundleSerializer::DecodeNamedQuery(
    ReadContext& context, const std::string& named_query_string) const {
  const json& named_query = Parse(named_query_string);

  if (named_query.is_discarded()) {
    context.Fail("Failed to parse string into json: " + named_query_string);
    return NamedQuery();
  }

  if (!named_query.contains("name") || !named_query.contains("bundledQuery") ||
      !named_query.contains("readTime")) {
    context.Fail("One of the field in NamedQuery cannot be found.");
    return NamedQuery();
  }

  return NamedQuery(ToString(context, named_query.at("name")),
                    DecodeBundledQuery(context, named_query.at("bundledQuery")),
                    DecodeSnapshotVersion(context, named_query.at("readTime")));
}

BundledQuery BundleSerializer::DecodeBundledQuery(
    util::ReadContext& context, const nlohmann::json& query) const {
  if (!query.contains("parent") || !query.contains("structuredQuery")) {
    context.Fail("One of the field in BundledQuery cannot be found.");
    return BundledQuery();
  }

  const json& structured_query = query.at("structuredQuery");
  VerifyStructuredQuery(context, structured_query);
  if (!context.ok()) {
    return BundledQuery();
  }

  ResourcePath parent = DecodeName(context, query.at("parent"));
  std::string collection_group_string;
  DecodeCollectionSource(context, parent, collection_group_string,
                         structured_query.at("from"));
  if (!context.ok()) {
    return BundledQuery();
  }
  std::shared_ptr<std::string> collection_group;
  if (!collection_group_string.empty()) {
    collection_group = std::make_shared<std::string>(collection_group_string);
  }

  auto filters = DecodeWhere(context, structured_query);
  if (!context.ok()) {
    return BundledQuery();
  }

  auto order_bys = DecodeOrderBy(context, structured_query);
  if (!context.ok()) {
    return BundledQuery();
  }

  auto start_at_bound = DecodeBound(context, structured_query, "startAt");
  if (!context.ok()) {
    return BundledQuery();
  }
  std::shared_ptr<Bound> start_at;
  if (!start_at_bound.position().empty()) {
    start_at = std::make_shared<Bound>(std::move(start_at_bound));
  }

  auto end_at_bound = DecodeBound(context, structured_query, "endAt");
  if (!context.ok()) {
    return BundledQuery();
  }
  std::shared_ptr<Bound> end_at;
  if (!end_at_bound.position().empty()) {
    end_at = std::make_shared<Bound>(std::move(end_at_bound));
  }

  int32_t limit = DecodeLimit(context, structured_query);
  if (!context.ok()) {
    return BundledQuery();
  }

  LimitType limit_type = DecodeLimitType(context, query);
  if (!context.ok()) {
    return BundledQuery();
  }

  return BundledQuery(Target(std::move(parent), std::move(collection_group),
                             std::move(filters), std::move(order_bys), limit,
                             std::move(start_at), std::move(end_at)),
                      limit_type);
}

ResourcePath BundleSerializer::DecodeName(ReadContext& context,
                                          const json& document_name) const {
  if (!document_name.is_string()) {
    context.Fail("Document name is not a string.");
    return ResourcePath();
  }
  auto path =
      ResourcePath::FromString(document_name.get_ref<const std::string&>());
  if (!rpc_serializer_.IsLocalResourceName(path)) {
    context.Fail("Resource name is not valid for current instance: " +
                 path.CanonicalString());
    return ResourcePath();
  }
  return path.PopFirst(5);
}

FilterList BundleSerializer::DecodeWhere(ReadContext& context,
                                         const json& query) const {
  if (!query.contains("where")) {
    return FilterList();
  }
  const auto& where = query.at("where");
  if (!where.is_object()) {
    context.Fail("Query's 'where' clause is not a json object.");
    return FilterList();
  }

  FilterList result;
  if (where.contains("compositeFilter")) {
    DecodeCompositeFilter(context, result, where.at("compositeFilter"));
  } else if (where.contains("fieldFilter")) {
    DecodeFieldFilter(context, result, where.at("fieldFilter"));
  } else if (where.contains("unaryFilter")) {
    DecodeUnaryFilter(context, result, where.at("unaryFilter"));
  }

  return result;
}

void BundleSerializer::DecodeFieldFilter(ReadContext& context,
                                         FilterList& result,
                                         const json& filter) const {
  if (!filter.contains("field") || !filter.contains("op") ||
      !filter.contains("value")) {
    context.Fail(
        "One of the 'field', 'op' or 'value' fields is missing from field "
        "filter");
    return;
  }

  FieldPath path = DecodeFieldReference(context, filter.at("field"));
  if (!context.ok()) {
    return;
  }

  auto op = DecodeFieldFilterOperator(context, filter.at("op"));
  if (!context.ok()) {
    return;
  }

  FieldValue value = DecodeValue(context, filter.at("value"));
  if (!context.ok()) {
    return;
  }

  result = result.push_back(FieldFilter::Create(path, op, value));
}

void BundleSerializer::DecodeCompositeFilter(ReadContext& context,
                                             FilterList& result,
                                             const json& filter) const {
  if (!filter.contains("op") || !filter.at("op").is_string()) {
    context.Fail(
        "The composite filter does not have an 'op' or 'op' is not a string");
    return;
  }

  if (filter.at("op").get_ref<const std::string&>() != "AND") {
    context.Fail("The SDK only supports composite filters of type 'AND'");
    return;
  }

  if (!filter.contains("filters") || !filter.at("filters").is_array()) {
    context.Fail(
        "The composite filter does not have an 'filter' or 'filter' is not an "
        "array");
    return;
  }

  auto filters = filter.at("filters").get_ref<const std::vector<json>&>();
  for (const auto& f : filters) {
    if (!f.is_object() || !f.contains("fieldFilter")) {
      context.Fail("Missing 'fieldFilter' field.");
      return;
    }

    DecodeFieldFilter(context, result, f.at("fieldFilter"));
    if (!context.ok()) {
      return;
    }
  }
}

Bound BundleSerializer::DecodeBound(ReadContext& context,
                                    const json& query,
                                    const std::string& bound_name) const {
  Bound default_bound = Bound({}, false);
  if (!query.contains(bound_name)) {
    return default_bound;
  }
  const json& bound_json = query.at(bound_name);
  if (!bound_json.is_object()) {
    context.Fail(
        "Fail to decode bound json because it is not encoded as an object.");
    return default_bound;
  }

  bool before = false;
  if (bound_json.contains("before")) {
    if (!bound_json.at("before").is_boolean()) {
      context.Fail(
          "Fail to decode bound json because its 'before' is not a boolean.");
      return default_bound;
    }
    before = bound_json.at("before").get<bool>();
  }

  std::vector<FieldValue> positions;
  if (bound_json.contains("values")) {
    if (!bound_json.at("values").is_array()) {
      context.Fail(
          "Fail to decode bound json because its 'values' is not an array.");
      return default_bound;
    }
    for (const auto& value :
         bound_json.at("values").get_ref<const std::vector<json>&>()) {
      positions.push_back(DecodeValue(context, value));
      if (!context.ok()) {
        return default_bound;
      }
    }
  }

  return Bound(std::move(positions), before);
}

FieldValue BundleSerializer::DecodeValue(ReadContext& context,
                                         const json& value) const {
  if (!value.is_object()) {
    context.Fail("'value' is not encoded as JSON object");
    return FieldValue();
  }

  if (value.contains("nullValue")) {
    return FieldValue::Null();
  } else if (value.contains("booleanValue")) {
    auto val = value.at("booleanValue");
    if (!val.is_boolean()) {
      context.Fail("'booleanValue' is not encoded as a valid boolean");
      return FieldValue();
    }
    return FieldValue::FromBoolean(val.get<bool>());
  } else if (value.contains("integerValue")) {
    return FieldValue::FromInteger(
        ToInt<int64_t>(context, value.at("integerValue")));
  } else if (value.contains("doubleValue")) {
    return FieldValue::FromDouble(ToDouble(context, value.at("doubleValue")));
  } else if (value.contains("timestampValue")) {
    auto val = DecodeTimestamp(context, value.at("timestampValue"));
    if (!context.ok()) {
      return FieldValue();
    }
    return FieldValue::FromTimestamp(val);
  } else if (value.contains("stringValue")) {
    auto val = ToString(context, value.at("stringValue"));
    if (!context.ok()) {
      return FieldValue();
    }
    return FieldValue::FromString(std::move(val));
  } else if (value.contains("bytesValue")) {
    return DecodeBytesValue(context, value.at("bytesValue"));
  } else if (value.contains("referenceValue")) {
    return DecodeReferenceValue(context, value.at("referenceValue"));
  } else if (value.contains("geoPointValue")) {
    return DecodeGeoPointValue(context, value.at("geoPointValue"));
  } else if (value.contains("arrayValue")) {
    return DecodeArrayValue(context, value.at("arrayValue"));
  } else if (value.contains("mapValue")) {
    return DecodeMapValue(context, value.at("mapValue"));
  } else {
    context.Fail("Failed to decode value, no type is recognized");
    return FieldValue();
  }
}

FieldValue BundleSerializer::DecodeMapValue(ReadContext& context,
                                            const json& map_json) const {
  if (!map_json.is_object() || !map_json.contains("fields")) {
    context.Fail("mapValue is not a valid map");
    return FieldValue();
  }
  const auto& fields = map_json.at("fields");
  if (!fields.is_object()) {
    context.Fail("mapValue's 'field' is not a valid map");
    return FieldValue();
  }

  immutable::SortedMap<std::string, FieldValue> field_values;
  for (auto it = fields.begin(); it != fields.end(); it++) {
    field_values =
        field_values.insert(it.key(), DecodeValue(context, it.value()));
    if (!context.ok()) {
      return FieldValue();
    }
  }

  return FieldValue::FromMap(std::move(field_values));
}

FieldValue BundleSerializer::DecodeArrayValue(ReadContext& context,
                                              const json& array_json) const {
  if (!array_json.is_object() || !array_json.contains("values")) {
    context.Fail("arrayValue is not a valid array object");
    return FieldValue();
  }
  if (!array_json.at("values").is_array()) {
    context.Fail("arrayValue is not a valid array");
    return FieldValue();
  }

  const auto& values =
      array_json.at("values").get_ref<const std::vector<json>&>();
  std::vector<FieldValue> field_values;
  for (const json& json_value : values) {
    field_values.push_back(DecodeValue(context, json_value));
    if (!context.ok()) {
      return FieldValue();
    }
  }

  return FieldValue::FromArray(std::move(field_values));
}

FieldValue BundleSerializer::DecodeReferenceValue(ReadContext& context,
                                                  const json& ref_json) const {
  auto ref_string = ToString(context, ref_json);
  if (!context.ok()) {
    return FieldValue();
  }

  return rpc_serializer_.DecodeReference(&context, ref_string);
}

BundledDocumentMetadata BundleSerializer::DecodeDocumentMetadata(
    util::ReadContext& context,
    const std::string& document_metadata_string) const {
  const json& document_metadata = Parse(document_metadata_string);

  if (document_metadata.is_discarded()) {
    context.Fail("Failed to parse string into json: " +
                 document_metadata_string);
    return BundledDocumentMetadata{};
  }

  if (!document_metadata.contains("name") ||
      !document_metadata.contains("readTime")) {
    context.Fail(
        "One of bundledDocumentMetadata's 'name' or 'readTime' is missing");
    return BundledDocumentMetadata{};
  }

  ResourcePath path = DecodeName(context, document_metadata.at("name"));
  if (!context.ok()) {
    return BundledDocumentMetadata{};
  }
  DocumentKey key = DocumentKey(path);

  SnapshotVersion read_time =
      DecodeSnapshotVersion(context, document_metadata.at("readTime"));
  if (!context.ok()) {
    return BundledDocumentMetadata{};
  }

  bool exists = false;
  if (document_metadata.contains("exists")) {
    if (!document_metadata.at("exists").is_boolean()) {
      context.Fail(
          "bundledDocumentMetadata's 'exists' is not encoded as a valid "
          "boolean");
      return BundledDocumentMetadata{};
    }
    exists = document_metadata.at("exists").get<bool>();
  }

  std::vector<std::string> queries;
  if (document_metadata.contains("queries")) {
    if (!document_metadata.at("queries").is_array()) {
      context.Fail(
          "bundledDocumentMetadata's 'queries' is not encoded as a valid "
          "array");
      return BundledDocumentMetadata{};
    }
    for (const json& query :
         document_metadata.at("queries").get_ref<const std::vector<json>&>()) {
      if (!query.is_string()) {
        context.Fail("Query name should be encoded as string");
        return BundledDocumentMetadata{};
      }

      queries.push_back(query.get<std::string>());
    }
  }

  return BundledDocumentMetadata(std::move(key), read_time, exists,
                                 std::move(queries));
}

BundleDocument BundleSerializer::DecodeDocument(
    util::ReadContext& context, const std::string& document_string) const {
  const json& document = Parse(document_string);

  if (document.is_discarded()) {
    context.Fail("Failed to parse document string into json: " +
                 document_string);
    return BundleDocument{};
  }

  if (!document.contains("name") || !document.contains("updateTime") ||
      !document.contains("fields")) {
    context.Fail(
        "One of bundleDocument's 'name', 'updateTime' or 'fields' is missing");
    return BundleDocument{};
  }

  ResourcePath path = DecodeName(context, document.at("name"));
  if (!context.ok()) {
    return BundleDocument{};
  }
  DocumentKey key = DocumentKey(path);

  SnapshotVersion update_time =
      DecodeSnapshotVersion(context, document.at("updateTime"));
  if (!context.ok()) {
    return BundleDocument{};
  }

  auto map_value = DecodeMapValue(context, document);
  if (!context.ok()) {
    return BundleDocument{};
  }

  return BundleDocument(Document(ObjectValue::FromMap(map_value.object_value()),
                                 std::move(key), update_time,
                                 model::DocumentState::kSynced));
}

}  // namespace bundle
}  // namespace firestore
}  // namespace firebase
