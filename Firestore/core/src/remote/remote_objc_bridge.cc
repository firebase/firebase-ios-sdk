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

#include "Firestore/core/src/remote/remote_objc_bridge.h"

#include <map>
#include <unordered_map>

#include "Firestore/core/src/core/database_info.h"
#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/model/aggregate_alias.h"
#include "Firestore/core/src/model/aggregate_field.h"
#include "Firestore/core/src/model/document.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/mutation.h"
#include "Firestore/core/src/model/snapshot_version.h"
#include "Firestore/core/src/nanopb/byte_string.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"
#include "Firestore/core/src/nanopb/writer.h"
#include "Firestore/core/src/remote/grpc_nanopb.h"
#include "Firestore/core/src/remote/grpc_util.h"
#include "Firestore/core/src/remote/watch_change.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/status.h"
#include "Firestore/core/src/util/statusor.h"
#include "grpcpp/support/status.h"

#include "absl/container/flat_hash_map.h"
#include "absl/strings/str_format.h"

namespace firebase {
namespace firestore {
namespace remote {

using core::DatabaseInfo;
using local::TargetData;
using model::AggregateField;
using model::Document;
using model::DocumentKey;
using model::Mutation;
using model::MutationResult;
using model::ObjectValue;
using model::SnapshotVersion;
using model::TargetId;
using nanopb::ByteString;
using nanopb::MakeArray;
using nanopb::Message;
using nanopb::Reader;
using remote::ByteBufferReader;
using remote::Serializer;
using util::StatusOr;

// WatchStreamSerializer

WatchStreamSerializer::WatchStreamSerializer(Serializer serializer)
    : serializer_{std::move(serializer)} {
}

Message<google_firestore_v1_ListenRequest>
WatchStreamSerializer::EncodeWatchRequest(const TargetData& query) const {
  Message<google_firestore_v1_ListenRequest> result;

  result->database = serializer_.EncodeDatabaseName();
  result->which_target_change =
      google_firestore_v1_ListenRequest_add_target_tag;
  result->add_target = serializer_.EncodeTarget(query);

  auto labels = serializer_.EncodeListenRequestLabels(query);
  if (!labels.empty()) {
    result->labels_count = nanopb::CheckedSize(labels.size());
    result->labels = MakeArray<google_firestore_v1_ListenRequest_LabelsEntry>(
        result->labels_count);

    pb_size_t i = 0;
    for (const auto& label : labels) {
      result->labels[i] = label;
      ++i;
    }
  }

  return result;
}

Message<google_firestore_v1_ListenRequest>
WatchStreamSerializer::EncodeUnwatchRequest(TargetId target_id) const {
  Message<google_firestore_v1_ListenRequest> result;

  result->database = serializer_.EncodeDatabaseName();
  result->which_target_change =
      google_firestore_v1_ListenRequest_remove_target_tag;
  result->remove_target = target_id;

  return result;
}

Message<google_firestore_v1_ListenResponse>
WatchStreamSerializer::ParseResponse(Reader* reader) const {
  return Message<google_firestore_v1_ListenResponse>::TryParse(reader);
}

std::unique_ptr<WatchChange> WatchStreamSerializer::DecodeWatchChange(
    nanopb::Reader* reader,
    google_firestore_v1_ListenResponse& response) const {
  return serializer_.DecodeWatchChange(reader->context(), response);
}

SnapshotVersion WatchStreamSerializer::DecodeSnapshotVersion(
    nanopb::Reader* reader,
    const google_firestore_v1_ListenResponse& response) const {
  return serializer_.DecodeVersionFromListenResponse(reader->context(),
                                                     response);
}

// WriteStreamSerializer

WriteStreamSerializer::WriteStreamSerializer(Serializer serializer)
    : serializer_{std::move(serializer)} {
}

Message<google_firestore_v1_WriteRequest>
WriteStreamSerializer::EncodeHandshake() const {
  Message<google_firestore_v1_WriteRequest> result;

  // The initial request cannot contain mutations, but must contain a project
  // ID.
  result->database = serializer_.EncodeDatabaseName();

  return result;
}

Message<google_firestore_v1_WriteRequest>
WriteStreamSerializer::EncodeWriteMutationsRequest(
    const std::vector<Mutation>& mutations,
    const ByteString& last_stream_token) const {
  Message<google_firestore_v1_WriteRequest> result;

  if (!mutations.empty()) {
    result->writes_count = nanopb::CheckedSize(mutations.size());
    result->writes = MakeArray<google_firestore_v1_Write>(result->writes_count);

    for (pb_size_t i = 0; i != result->writes_count; ++i) {
      result->writes[i] = serializer_.EncodeMutation(mutations[i]);
    }
  }

  result->stream_token = nanopb::CopyBytesArray(last_stream_token.get());

  return result;
}

Message<google_firestore_v1_WriteRequest>
WriteStreamSerializer::EncodeEmptyMutationsList(
    const ByteString& last_stream_token) const {
  return EncodeWriteMutationsRequest({}, last_stream_token);
}

Message<google_firestore_v1_WriteResponse> WriteStreamSerializer::ParseResponse(
    Reader* reader) const {
  return Message<google_firestore_v1_WriteResponse>::TryParse(reader);
}

SnapshotVersion WriteStreamSerializer::DecodeCommitVersion(
    nanopb::Reader* reader,
    const google_firestore_v1_WriteResponse& proto) const {
  return serializer_.DecodeVersion(reader->context(), proto.commit_time);
}

std::vector<MutationResult> WriteStreamSerializer::DecodeMutationResults(
    nanopb::Reader* reader, google_firestore_v1_WriteResponse& proto) const {
  SnapshotVersion commit_version = DecodeCommitVersion(reader, proto);
  if (!reader->ok()) {
    return {};
  }

  google_firestore_v1_WriteResult* writes = proto.write_results;
  pb_size_t count = proto.write_results_count;
  std::vector<MutationResult> results;
  results.reserve(count);

  for (pb_size_t i = 0; i != count; ++i) {
    results.push_back(serializer_.DecodeMutationResult(
        reader->context(), writes[i], commit_version));
  }

  return results;
}

// DatastoreSerializer

DatastoreSerializer::DatastoreSerializer(const DatabaseInfo& database_info)
    : serializer_{database_info.database_id()} {
}

Message<google_firestore_v1_CommitRequest>
DatastoreSerializer::EncodeCommitRequest(
    const std::vector<Mutation>& mutations) const {
  Message<google_firestore_v1_CommitRequest> result;

  result->database = serializer_.EncodeDatabaseName();

  if (!mutations.empty()) {
    result->writes_count = nanopb::CheckedSize(mutations.size());
    result->writes = MakeArray<google_firestore_v1_Write>(result->writes_count);
    pb_size_t i = 0;
    for (const Mutation& mutation : mutations) {
      result->writes[i] = serializer_.EncodeMutation(mutation);
      ++i;
    }
  }

  return result;
}

Message<google_firestore_v1_BatchGetDocumentsRequest>
DatastoreSerializer::EncodeLookupRequest(
    const std::vector<DocumentKey>& keys) const {
  Message<google_firestore_v1_BatchGetDocumentsRequest> result;

  result->database = serializer_.EncodeDatabaseName();
  if (!keys.empty()) {
    result->documents_count = nanopb::CheckedSize(keys.size());
    result->documents = MakeArray<pb_bytes_array_t*>(result->documents_count);
    pb_size_t i = 0;
    for (const DocumentKey& key : keys) {
      result->documents[i] = serializer_.EncodeKey(key);
      ++i;
    }
  }

  return result;
}

StatusOr<std::vector<model::Document>>
DatastoreSerializer::MergeLookupResponses(
    const std::vector<grpc::ByteBuffer>& responses) const {
  // Sort by key.
  std::map<DocumentKey, Document> results;

  for (const auto& response : responses) {
    ByteBufferReader reader{response};
    auto message =
        Message<google_firestore_v1_BatchGetDocumentsResponse>::TryParse(
            &reader);

    Document doc = serializer_.DecodeMaybeDocument(reader.context(), *message);
    if (!reader.ok()) {
      return reader.status();
    }

    results[doc->key()] = std::move(doc);
  }

  std::vector<Document> docs;
  docs.reserve(results.size());
  for (const auto& kv : results) {
    docs.push_back(kv.second);
  }

  StatusOr<std::vector<Document>> result{std::move(docs)};
  return result;
}

// TODO(b/443765747) Revert back to absl::flat_hash_map after the absl version
// is upgraded to later than 20250127.0
Message<google_firestore_v1_RunAggregationQueryRequest>
DatastoreSerializer::EncodeAggregateQueryRequest(
    const core::Query& query,
    const std::vector<AggregateField>& aggregates,
    std::unordered_map<std::string, std::string>& aliasMap) const {
  Message<google_firestore_v1_RunAggregationQueryRequest> result;
  auto encodedTarget = serializer_.EncodeQueryTarget(query.ToAggregateTarget());
  result->parent = encodedTarget.parent;
  result->which_query_type =
      google_firestore_v1_RunAggregationQueryRequest_structured_aggregation_query_tag;  // NOLINT

  result->query_type.structured_aggregation_query.which_query_type =
      google_firestore_v1_StructuredAggregationQuery_structured_query_tag;
  result->query_type.structured_aggregation_query.structured_query =
      encodedTarget.structured_query;

  // De-duplicate aggregates based on the alias.
  // Since aliases are auto-computed from the operation and path,
  // equal aggregate will have the same alias.
  // TODO(b/443765747) Revert back to absl::flat_hash_map after the absl version
  // is upgraded to later than 20250127.0
  std::unordered_map<std::string, AggregateField> uniqueAggregates;
  for (const AggregateField& aggregate : aggregates) {
    auto pair = std::pair<std::string, AggregateField>(
        aggregate.alias.StringValue(), aggregate);
    uniqueAggregates.insert(std::move(pair));
  }

  pb_size_t count = static_cast<pb_size_t>(uniqueAggregates.size());
  pb_size_t aggregationNum = 0;
  result->query_type.structured_aggregation_query.aggregations_count = count;
  result->query_type.structured_aggregation_query.aggregations =
      MakeArray<_google_firestore_v1_StructuredAggregationQuery_Aggregation>(
          count);
  for (const auto& aggregatePair : uniqueAggregates) {
    // Map all client-side aliases to a unique short-form
    // alias. This avoids issues with client-side aliases that
    // exceed the 1500-byte string size limit.
    std::string clientAlias = aggregatePair.first;
    std::string serverAlias = absl::StrFormat("aggregation_%d", aggregationNum);
    auto pair = std::pair<std::string, std::string>(serverAlias, clientAlias);
    aliasMap.insert(std::move(pair));

    // Send the server alias in the request to the backend
    result->query_type.structured_aggregation_query.aggregations[aggregationNum]
        .alias = nanopb::MakeBytesArray(serverAlias);

    if (aggregatePair.second.op == AggregateField::OpKind::Count) {
      result->query_type.structured_aggregation_query
          .aggregations[aggregationNum]
          .which_operator =
          google_firestore_v1_StructuredAggregationQuery_Aggregation_count_tag;

      result->query_type.structured_aggregation_query
          .aggregations[aggregationNum]
          .count =
          google_firestore_v1_StructuredAggregationQuery_Aggregation_Count{};
    } else if (aggregatePair.second.op == AggregateField::OpKind::Sum) {
      google_firestore_v1_StructuredQuery_FieldReference field{};

      field.field_path = nanopb::MakeBytesArray(
          aggregatePair.second.fieldPath.CanonicalString());

      result->query_type.structured_aggregation_query
          .aggregations[aggregationNum]
          .which_operator =
          google_firestore_v1_StructuredAggregationQuery_Aggregation_sum_tag;

      result->query_type.structured_aggregation_query
          .aggregations[aggregationNum]
          .sum =
          google_firestore_v1_StructuredAggregationQuery_Aggregation_Sum{field};

    } else if (aggregatePair.second.op == AggregateField::OpKind::Avg) {
      google_firestore_v1_StructuredQuery_FieldReference field{};
      field.field_path = nanopb::MakeBytesArray(
          aggregatePair.second.fieldPath.CanonicalString());

      result->query_type.structured_aggregation_query
          .aggregations[aggregationNum]
          .which_operator =
          google_firestore_v1_StructuredAggregationQuery_Aggregation_avg_tag;

      result->query_type.structured_aggregation_query
          .aggregations[aggregationNum]
          .avg =
          google_firestore_v1_StructuredAggregationQuery_Aggregation_Avg{field};
    }

    ++aggregationNum;
  }

  return result;
}

// TODO(b/443765747) Revert back to absl::flat_hash_map after the absl version
// is upgraded to later than 20250127.0
util::StatusOr<ObjectValue> DatastoreSerializer::DecodeAggregateQueryResponse(
    const grpc::ByteBuffer& response,
    const std::unordered_map<std::string, std::string>& aliasMap) const {
  ByteBufferReader reader{response};
  auto message =
      Message<google_firestore_v1_RunAggregationQueryResponse>::TryParse(
          &reader);
  if (!reader.ok()) {
    return reader.status();
  }

  HARD_ASSERT(message->result.aggregate_fields != nullptr);

  return ObjectValue::FromAggregateFieldsEntry(
      message->result.aggregate_fields, message->result.aggregate_fields_count,
      aliasMap);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
