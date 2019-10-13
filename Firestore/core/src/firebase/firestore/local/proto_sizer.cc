/*
 * Copyright 2019 Google
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

#include "Firestore/core/src/firebase/firestore/local/proto_sizer.h"

#include "Firestore/Protos/nanopb/firestore/local/maybe_document.nanopb.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/maybe_document.h"
#include "Firestore/core/src/firebase/firestore/nanopb/byte_string.h"
#include "Firestore/core/src/firebase/firestore/nanopb/message.h"

namespace firebase {
namespace firestore {
namespace local {

namespace {

using model::DocumentKey;
using model::MaybeDocument;
using nanopb::ByteString;
using nanopb::make_message;
using nanopb::Message;

}  // namespace

ProtoSizer::ProtoSizer(LocalSerializer serializer)
    : serializer_(std::move(serializer)) {
}

int64_t ProtoSizer::CalculateByteSize(const MaybeDocument& maybe_doc) const {
  return serializer_.EncodeMaybeDocument(maybe_doc).ToByteString().size();
}

int64_t ProtoSizer::CalculateByteSize(const model::MutationBatch& batch) const {
  auto message = make_message(serializer_.EncodeMutationBatch(batch));
  return message.ToByteString().size();
}

int64_t ProtoSizer::CalculateByteSize(const QueryData& query_data) const {
  return serializer_.EncodeQueryData(query_data).ToByteString().size();
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
