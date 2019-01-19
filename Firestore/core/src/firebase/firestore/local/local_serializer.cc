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
#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/core/src/firebase/firestore/core/query.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/no_document.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
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
using nanopb::Writer;
using remote::MakeArray;
using util::Status;
using util::StringFormat;

firestore_client_MaybeDocument LocalSerializer::EncodeMaybeDocument(
    const MaybeDocument& maybe_doc) const {
  firestore_client_MaybeDocument result{};

  switch (maybe_doc.type()) {
    case MaybeDocument::Type::Document:
      result.which_document_type = firestore_client_MaybeDocument_document_tag;
      result.document = EncodeDocument(static_cast<const Document&>(maybe_doc));
      return result;

    case MaybeDocument::Type::NoDocument:
      result.which_document_type =
          firestore_client_MaybeDocument_no_document_tag;
      result.no_document =
          EncodeNoDocument(static_cast<const NoDocument&>(maybe_doc));
      return result;

    case MaybeDocument::Type::UnknownDocument:
      // TODO(rsgowman): Implement
      abort();

    case MaybeDocument::Type::Unknown:
      // TODO(rsgowman): Error handling
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
          StringFormat("Invalid MaybeDocument document type: %s. Expected "
                       "'no_document' (%s) or 'document' (%s)",
                       proto.which_document_type,
                       firestore_client_MaybeDocument_no_document_tag,
                       firestore_client_MaybeDocument_document_tag));
      return nullptr;
  }

  UNREACHABLE();
}

google_firestore_v1_Document LocalSerializer::EncodeDocument(
    const Document& doc) const {
  google_firestore_v1_Document result{};

  result.name =
      rpc_serializer_.EncodeString(rpc_serializer_.EncodeKey(doc.key()));

  // Encode Document.fields (unless it's empty)
  size_t count = doc.data().object_value().internal_value.size();
  result.fields_count = static_cast<pb_size_t>(count);
  result.fields = MakeArray<google_firestore_v1_Document_FieldsEntry>(count);
  int i = 0;
  for (const auto& kv : doc.data().object_value().internal_value) {
    result.fields[i].key = rpc_serializer_.EncodeString(kv.first);
    result.fields[i].value = rpc_serializer_.EncodeFieldValue(kv.second);
    i++;
  }

  result.update_time = rpc_serializer_.EncodeVersion(doc.version());

  // Ignore Document.create_time. (We don't use this in our on-disk protos.)

  return result;
}

firestore_client_NoDocument LocalSerializer::EncodeNoDocument(
    const NoDocument& no_doc) const {
  firestore_client_NoDocument result{};

  result.name =
      rpc_serializer_.EncodeString(rpc_serializer_.EncodeKey(no_doc.key()));
  result.read_time = rpc_serializer_.EncodeVersion(no_doc.version());

  return result;
}

std::unique_ptr<NoDocument> LocalSerializer::DecodeNoDocument(
    Reader* reader, const firestore_client_NoDocument& proto) const {
  if (!reader->status().ok()) return nullptr;

  SnapshotVersion version =
      rpc_serializer_.DecodeSnapshotVersion(reader, proto.read_time);
  if (!reader->status().ok()) return nullptr;

  // TODO(rsgowman): Fix hardcoding of has_committed_mutations.
  // Instead, we should grab this from the proto (see other ports). However,
  // we'll defer until the nanopb-master gets merged to master.
  return absl::make_unique<NoDocument>(
      rpc_serializer_.DecodeKey(reader,
                                rpc_serializer_.DecodeString(proto.name)),
      std::move(version),
      /*has_committed_mutations=*/false);
}

firestore_client_Target LocalSerializer::EncodeQueryData(
    const QueryData& query_data) const {
  firestore_client_Target result{};

  result.target_id = query_data.target_id();
  result.last_listen_sequence_number = query_data.sequence_number();
  result.snapshot_version = rpc_serializer_.EncodeTimestamp(
      query_data.snapshot_version().timestamp());
  result.resume_token = rpc_serializer_.EncodeBytes(query_data.resume_token());

  const Query& query = query_data.query();
  if (query.IsDocumentQuery()) {
    // TODO(rsgowman): Implement. Probably like this (once EncodeDocumentsTarget
    // exists):
    /*
    result.which_target_type = firestore_client_Target_document_tag;
    result.documents = rpc_serializer_.EncodeDocumentsTarget(query);
    */
    abort();
  } else {
    result.which_target_type = firestore_client_Target_query_tag;
    result.query = rpc_serializer_.EncodeQueryTarget(query);
  }

  return result;
}

QueryData LocalSerializer::DecodeQueryData(
    Reader* reader, const firestore_client_Target& proto) const {
  if (!reader->status().ok()) return QueryData::Invalid();

  model::TargetId target_id = proto.target_id;
  // TODO(rgowman): How to handle truncation of integer types?
  model::ListenSequenceNumber sequence_number =
      static_cast<model::ListenSequenceNumber>(
          proto.last_listen_sequence_number);
  SnapshotVersion version =
      rpc_serializer_.DecodeSnapshotVersion(reader, proto.snapshot_version);
  std::vector<uint8_t> resume_token =
      rpc_serializer_.DecodeBytes(proto.resume_token);
  Query query = Query::Invalid();

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

  if (!reader->status().ok()) return QueryData::Invalid();
  return QueryData(std::move(query), target_id, sequence_number,
                   QueryPurpose::kListen, std::move(version),
                   std::move(resume_token));
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
