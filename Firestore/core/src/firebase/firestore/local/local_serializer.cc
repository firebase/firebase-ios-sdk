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

#include "Firestore/core/src/firebase/firestore/local/local_serializer.h"

#include <cstdlib>
#include <string>
#include <utility>

#include "Firestore/Protos/nanopb/firestore/local/maybe_document.nanopb.h"
#include "Firestore/Protos/nanopb/firestore/local/target.nanopb.h"
#include "Firestore/Protos/nanopb/google/firestore/v1beta1/document.nanopb.h"
#include "Firestore/core/src/firebase/firestore/core/query.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/no_document.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/nanopb/tag.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace local {

using core::Query;
using model::ObjectValue;
using model::SnapshotVersion;
using nanopb::Reader;
using nanopb::Tag;
using nanopb::Writer;
using util::Status;

Status LocalSerializer::EncodeMaybeDocument(
    const model::MaybeDocument& document,
    std::vector<uint8_t>* out_bytes) const {
  Writer writer = Writer::Wrap(out_bytes);
  EncodeMaybeDocument(&writer, document);
  return writer.status();
}

void LocalSerializer::EncodeMaybeDocument(
    Writer* writer, const model::MaybeDocument& maybe_doc) const {
  switch (maybe_doc.type()) {
    case model::MaybeDocument::Type::Document:
      writer->WriteTag(
          {PB_WT_STRING, firestore_client_MaybeDocument_document_tag});
      writer->WriteNestedMessage([&](Writer* writer) {
        EncodeDocument(writer, static_cast<const model::Document&>(maybe_doc));
      });
      return;

    case model::MaybeDocument::Type::NoDocument:
      writer->WriteTag(
          {PB_WT_STRING, firestore_client_MaybeDocument_no_document_tag});
      writer->WriteNestedMessage([&](Writer* writer) {
        EncodeNoDocument(writer,
                         static_cast<const model::NoDocument&>(maybe_doc));
      });
      return;

    case model::MaybeDocument::Type::Unknown:
      // TODO(rsgowman)
      abort();
  }

  UNREACHABLE();
}

std::unique_ptr<model::MaybeDocument> LocalSerializer::DecodeMaybeDocument(
    Reader* reader) const {
  if (!reader->status().ok()) return nullptr;

  std::unique_ptr<model::MaybeDocument> result;

  while (reader->bytes_left()) {
    Tag tag = reader->ReadTag();
    if (!reader->status().ok()) return nullptr;

    // Ensure the tag matches the wire type
    switch (tag.field_number) {
      case firestore_client_MaybeDocument_document_tag:
        if (!reader->RequireWireType(PB_WT_STRING, tag)) return nullptr;

        // TODO(rsgowman): If multiple 'document' values are found, we should
        // merge them (rather than using the last one.)
        result = reader->ReadNestedMessage<std::unique_ptr<model::Document>>(
            [&](Reader* reader) -> std::unique_ptr<model::Document> {
              return rpc_serializer_.DecodeDocument(reader);
            });
        break;

      case firestore_client_MaybeDocument_no_document_tag:
        if (!reader->RequireWireType(PB_WT_STRING, tag)) return nullptr;

        // TODO(rsgowman): If multiple 'no_document' values are found, we should
        // merge them (rather than using the last one.)
        result = reader->ReadNestedMessage<std::unique_ptr<model::NoDocument>>(
            [&](Reader* reader) { return DecodeNoDocument(reader); });
        break;

      default:
        // Unknown tag. According to the proto spec, we need to ignore these.
        reader->SkipField(tag);
    }
  }

  if (!result) {
    reader->set_status(Status(FirestoreErrorCode::DataLoss,
                              "Invalid MaybeDocument message: Neither "
                              "'no_document' nor 'document' fields set."));
  }
  return result;
}

void LocalSerializer::EncodeDocument(Writer* writer,
                                     const model::Document& doc) const {
  // Encode Document.name
  writer->WriteTag({PB_WT_STRING, google_firestore_v1beta1_Document_name_tag});
  writer->WriteString(rpc_serializer_.EncodeKey(doc.key()));

  // Encode Document.fields (unless it's empty)
  const ObjectValue& object_value = doc.data().object_value();
  if (!object_value.internal_value.empty()) {
    rpc_serializer_.EncodeObjectMap(
        writer, object_value.internal_value,
        google_firestore_v1beta1_Document_fields_tag,
        google_firestore_v1beta1_Document_FieldsEntry_key_tag,
        google_firestore_v1beta1_Document_FieldsEntry_value_tag);
  }

  // Encode Document.update_time
  writer->WriteTag(
      {PB_WT_STRING, google_firestore_v1beta1_Document_update_time_tag});
  writer->WriteNestedMessage([&](Writer* writer) {
    rpc_serializer_.EncodeVersion(writer, doc.version());
  });

  // Ignore Document.create_time. (We don't use this in our on-disk protos.)
}

void LocalSerializer::EncodeNoDocument(Writer* writer,
                                       const model::NoDocument& no_doc) const {
  // Encode NoDocument.name
  writer->WriteTag({PB_WT_STRING, firestore_client_NoDocument_name_tag});
  writer->WriteString(rpc_serializer_.EncodeKey(no_doc.key()));

  // Encode NoDocument.read_time
  writer->WriteTag({PB_WT_STRING, firestore_client_NoDocument_read_time_tag});
  writer->WriteNestedMessage([&](Writer* writer) {
    rpc_serializer_.EncodeVersion(writer, no_doc.version());
  });
}

util::StatusOr<std::unique_ptr<model::MaybeDocument>>
LocalSerializer::DecodeMaybeDocument(const uint8_t* bytes,
                                     size_t length) const {
  Reader reader = Reader::Wrap(bytes, length);
  std::unique_ptr<model::MaybeDocument> maybe_doc =
      DecodeMaybeDocument(&reader);
  if (reader.status().ok()) {
    return std::move(maybe_doc);
  } else {
    return reader.status();
  }
}

std::unique_ptr<model::NoDocument> LocalSerializer::DecodeNoDocument(
    Reader* reader) const {
  if (!reader->status().ok()) return nullptr;

  std::string name;
  SnapshotVersion version = SnapshotVersion::None();

  while (reader->bytes_left()) {
    Tag tag = reader->ReadTag();
    if (!reader->status().ok()) return nullptr;

    // Ensure the tag matches the wire type
    switch (tag.field_number) {
      case firestore_client_NoDocument_name_tag:
        if (!reader->RequireWireType(PB_WT_STRING, tag)) return nullptr;
        name = reader->ReadString();
        break;

      case firestore_client_NoDocument_read_time_tag:
        if (!reader->RequireWireType(PB_WT_STRING, tag)) return nullptr;
        version = SnapshotVersion{reader->ReadNestedMessage<Timestamp>(
            rpc_serializer_.DecodeTimestamp)};
        break;

      default:
        // Unknown tag. According to the proto spec, we need to ignore these.
        reader->SkipField(tag);
        break;
    }
  }

  return absl::make_unique<model::NoDocument>(rpc_serializer_.DecodeKey(name),
                                              version);
}

util::Status LocalSerializer::EncodeQueryData(
    const QueryData& query_data, std::vector<uint8_t>* out_bytes) const {
  HARD_ASSERT(QueryPurpose::kListen == query_data.purpose(),
              "Only queries with purpose %s may be stored, got %s",
              QueryPurpose::kListen, query_data.purpose());
  Writer writer = Writer::Wrap(out_bytes);
  EncodeQueryData(&writer, query_data);
  return writer.status();
}

void LocalSerializer::EncodeQueryData(Writer* writer,
                                      const QueryData& query_data) const {
  if (!writer->status().ok()) return;

  writer->WriteTag({PB_WT_VARINT, firestore_client_Target_target_id_tag});
  writer->WriteInteger(query_data.target_id());

  writer->WriteTag(
      {PB_WT_STRING, firestore_client_Target_snapshot_version_tag});
  writer->WriteNestedMessage([&](Writer* writer) {
    rpc_serializer_.EncodeTimestamp(writer,
                                    query_data.snapshot_version().timestamp());
  });

  writer->WriteTag({PB_WT_STRING, firestore_client_Target_resume_token_tag});
  writer->WriteBytes(query_data.resume_token());

  const Query& query = query_data.query();
  if (query.IsDocumentQuery()) {
    // TODO(rsgowman): Implement. Probably like this (once EncodeDocumentsTarget
    // exists):
    /*
    writer->WriteTag({PB_WT_STRING, firestore_client_Target_documents_tag});
    writer->WriteNestedMessage([&](Writer* writer) {
      rpc_serializer_.EncodeDocumentsTarget(writer, query);
    });
    */
    abort();
  } else {
    writer->WriteTag({PB_WT_STRING, firestore_client_Target_query_tag});
    writer->WriteNestedMessage([&](Writer* writer) {
      rpc_serializer_.EncodeQueryTarget(writer, query);
    });
  }
}

util::StatusOr<QueryData> LocalSerializer::DecodeQueryData(
    const uint8_t* bytes, size_t length) const {
  Reader reader = Reader::Wrap(bytes, length);
  QueryData query_data = DecodeQueryData(&reader);
  if (reader.status().ok()) {
    return query_data;
  } else {
    return reader.status();
  }
}

QueryData LocalSerializer::DecodeQueryData(Reader* reader) const {
  if (!reader->status().ok()) return QueryData::Invalid();

  int64_t target_id = 0;
  SnapshotVersion version = SnapshotVersion::None();
  std::vector<uint8_t> resume_token;
  Query query = Query::Invalid();

  while (reader->bytes_left()) {
    Tag tag = reader->ReadTag();
    if (!reader->status().ok()) return QueryData::Invalid();

    switch (tag.field_number) {
      case firestore_client_Target_target_id_tag:
        if (!reader->RequireWireType(PB_WT_VARINT, tag))
          return QueryData::Invalid();
        target_id = reader->ReadInteger();
        break;

      case firestore_client_Target_snapshot_version_tag:
        if (!reader->RequireWireType(PB_WT_STRING, tag))
          return QueryData::Invalid();
        version = SnapshotVersion{reader->ReadNestedMessage<Timestamp>(
            rpc_serializer_.DecodeTimestamp)};
        break;

      case firestore_client_Target_resume_token_tag:
        if (!reader->RequireWireType(PB_WT_STRING, tag))
          return QueryData::Invalid();
        resume_token = reader->ReadBytes();
        break;

      case firestore_client_Target_query_tag:
        if (!reader->RequireWireType(PB_WT_STRING, tag))
          return QueryData::Invalid();
        // TODO(rsgowman): Clear 'documents' field (since query and documents
        // are part of a 'oneof').
        query =
            reader->ReadNestedMessage<Query>(rpc_serializer_.DecodeQueryTarget);
        break;

      case firestore_client_Target_documents_tag:
        if (!reader->RequireWireType(PB_WT_STRING, tag))
          return QueryData::Invalid();
        // Clear 'query' field (since query and documents are part of a 'oneof')
        query = Query::Invalid();
        // TODO(rsgowman): Implement.
        abort();

      default:
        // Unknown tag. According to the proto spec, we need to ignore these.
        reader->SkipField(tag);
        break;
    }
  }

  return QueryData(std::move(query), target_id, QueryPurpose::kListen,
                   std::move(version), std::move(resume_token));
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
