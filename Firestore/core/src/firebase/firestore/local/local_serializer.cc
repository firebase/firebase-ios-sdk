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
#include "Firestore/core/src/firebase/firestore/util/string_format.h"

namespace firebase {
namespace firestore {
namespace local {

using core::Query;
using model::Document;
using model::MaybeDocument;
using model::NoDocument;
using model::ObjectValue;
using model::SnapshotVersion;
using nanopb::Reader;
using nanopb::Tag;
using nanopb::Writer;
using util::Status;
using util::StringFormat;

void LocalSerializer::EncodeMaybeDocument(
    Writer* writer, const MaybeDocument& maybe_doc) const {
  switch (maybe_doc.type()) {
    case MaybeDocument::Type::Document:
      writer->WriteTag(
          {PB_WT_STRING, firestore_client_MaybeDocument_document_tag});
      writer->WriteNestedMessage([&](Writer* writer) {
        EncodeDocument(writer, static_cast<const Document&>(maybe_doc));
      });
      return;

    case MaybeDocument::Type::NoDocument:
      writer->WriteTag(
          {PB_WT_STRING, firestore_client_MaybeDocument_no_document_tag});
      writer->WriteNestedMessage([&](Writer* writer) {
        EncodeNoDocument(writer, static_cast<const NoDocument&>(maybe_doc));
      });
      return;

    case MaybeDocument::Type::Unknown:
      // TODO(rsgowman)
      abort();
  }

  UNREACHABLE();
}

std::unique_ptr<MaybeDocument> LocalSerializer::DecodeMaybeDocument(
    Reader* reader, const firestore_client_MaybeDocument& proto) const {
  if (!reader->status().ok()) return nullptr;

  switch (proto.which_document_type) {
    case firestore_client_MaybeDocument_document_tag:
      return rpc_serializer_.DecodeDocument(reader, proto.document);

    case firestore_client_MaybeDocument_no_document_tag:
      return DecodeNoDocument(reader, proto.no_document);

    default:
      reader->Fail(
          "Invalid MaybeDocument message: Neither 'no_document' nor 'document' "
          "fields set.");
      return nullptr;
  }

  UNREACHABLE();
}

void LocalSerializer::EncodeDocument(Writer* writer,
                                     const Document& doc) const {
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
                                       const NoDocument& no_doc) const {
  // Encode NoDocument.name
  writer->WriteTag({PB_WT_STRING, firestore_client_NoDocument_name_tag});
  writer->WriteString(rpc_serializer_.EncodeKey(no_doc.key()));

  // Encode NoDocument.read_time
  writer->WriteTag({PB_WT_STRING, firestore_client_NoDocument_read_time_tag});
  writer->WriteNestedMessage([&](Writer* writer) {
    rpc_serializer_.EncodeVersion(writer, no_doc.version());
  });
}

std::unique_ptr<NoDocument> LocalSerializer::DecodeNoDocument(
    Reader* reader, const firestore_client_NoDocument& proto) const {
  if (!reader->status().ok()) return nullptr;

  absl::optional<SnapshotVersion> version =
      rpc_serializer_.DecodeSnapshotVersion(reader, proto.read_time);

  if (!reader->status().ok()) return nullptr;
  return absl::make_unique<NoDocument>(
      rpc_serializer_.DecodeKey(rpc_serializer_.DecodeString(proto.name)),
      *std::move(version));
}

void LocalSerializer::EncodeQueryData(Writer* writer,
                                      const QueryData& query_data) const {
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

absl::optional<QueryData> LocalSerializer::DecodeQueryData(
    Reader* reader, const firestore_client_Target& proto) const {
  if (!reader->status().ok()) return absl::nullopt;

  model::TargetId target_id = proto.target_id;
  absl::optional<SnapshotVersion> version =
      rpc_serializer_.DecodeSnapshotVersion(reader, proto.snapshot_version);
  std::vector<uint8_t> resume_token =
      rpc_serializer_.DecodeBytes(proto.resume_token);
  absl::optional<Query> query = Query::Invalid();

  switch (proto.which_target_type) {
    case firestore_client_Target_query_tag:
      query = rpc_serializer_.DecodeQueryTarget(reader, proto.query);
      break;

    case firestore_client_Target_documents_tag:
      // TODO(rsgowman): Implement.
      abort();

    default:
      reader->Fail(
          StringFormat("Unknown target_type: %s", proto.which_target_type));
  }

  if (!reader->status().ok()) return absl::nullopt;
  return QueryData(*std::move(query), target_id, QueryPurpose::kListen,
                   *std::move(version), std::move(resume_token));
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
