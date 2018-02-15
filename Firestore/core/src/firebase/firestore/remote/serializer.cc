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

#include "Firestore/core/src/firebase/firestore/remote/serializer.h"

#include <pb_decode.h>
#include <pb_encode.h>

namespace firebase {
namespace firestore {
namespace remote {

using firebase::firestore::model::FieldValue;

Serializer::TypedValue Serializer::EncodeFieldValue(
    const FieldValue& field_value) {
  Serializer::TypedValue proto_value{
      field_value.type(), google_firestore_v1beta1_Value_init_default};
  switch (field_value.type()) {
    case FieldValue::Type::Null:
      proto_value.value.null_value = google_protobuf_NullValue_NULL_VALUE;
      break;
    default:
      // TODO(rsgowman): implement the other types
      abort();
  }
  return proto_value;
}

void Serializer::EncodeTypedValue(const TypedValue& value,
                                  std::vector<uint8_t>* out_bytes) {
  bool status;
  // TODO(rsgowman): how large should the output buffer be? Do some
  // investigation to see if we can get nanopb to tell us how much space it's
  // going to need.
  uint8_t buf[1024];
  pb_ostream_t stream = pb_ostream_from_buffer(buf, sizeof(buf));
  switch (value.type) {
    case FieldValue::Type::Null:
      status = pb_encode_tag(&stream, PB_WT_VARINT,
                             google_firestore_v1beta1_Value_null_value_tag);
      if (!status) {
        // TODO(rsgowman): figure out error handling
        abort();
      }

      status = pb_encode_varint(&stream, value.value.null_value);
      if (!status) {
        // TODO(rsgowman): figure out error handling
        abort();
      }

      out_bytes->insert(out_bytes->end(), buf, buf + stream.bytes_written);

      break;

    default:
      // TODO(rsgowman): implement the other types
      abort();
  }
}

FieldValue Serializer::DecodeFieldValue(
    const Serializer::TypedValue& value_proto) {
  switch (value_proto.type) {
    case FieldValue::Type::Null:
      return FieldValue::NullValue();
    default:
      // TODO(rsgowman): implement the other types
      abort();
  }
}

Serializer::TypedValue Serializer::DecodeTypedValue(const uint8_t* bytes,
                                                    size_t length) {
  pb_istream_t stream = pb_istream_from_buffer(bytes, length);
  pb_wire_type_t wire_type;
  uint32_t tag;
  bool eof;
  bool status = pb_decode_tag(&stream, &wire_type, &tag, &eof);
  if (!status || wire_type != PB_WT_VARINT) {
    // TODO(rsgowman): figure out error handling
    abort();
  }

  switch (tag) {
    case google_firestore_v1beta1_Value_null_value_tag:
      return Serializer::TypedValue{
          FieldValue::Type::Null, google_firestore_v1beta1_Value_init_default};
    default:
      // TODO(rsgowman): figure out error handling
      abort();
  }
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
