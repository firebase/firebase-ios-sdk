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

#include <functional>
#include <map>
#include <string>
#include <utility>

#include "Firestore/Protos/nanopb/google/firestore/v1beta1/document.pb.h"
#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"

namespace firebase {
namespace firestore {
namespace remote {

using firebase::firestore::model::FieldValue;
using firebase::firestore::model::ObjectValue;
using firebase::firestore::util::Status;

namespace {

class Writer;

class Reader;

void EncodeObject(Writer* writer, const ObjectValue& object_value);

ObjectValue DecodeObject(Reader* reader);

/**
 * Represents a nanopb tag.
 *
 * field_number is one of the field tags that nanopb generates based off of
 * the proto messages. They're typically named in the format:
 * <parentNameSpace>_<childNameSpace>_<message>_<field>_tag, e.g.
 * google_firestore_v1beta1_Document_name_tag.
 */
struct Tag {
  pb_wire_type_t wire_type;
  uint32_t field_number;
};

/**
 * Docs TODO(rsgowman). But currently, this just wraps the underlying nanopb
 * pb_ostream_t. Also doc how to check status.
 */
class Writer {
 public:
  /**
   * Creates an output stream that writes to the specified vector. Note that
   * this vector pointer must remain valid for the lifetime of this Writer.
   *
   * (This is roughly equivalent to the nanopb function
   * pb_ostream_from_buffer())
   *
   * @param out_bytes where the output should be serialized to.
   */
  static Writer Wrap(std::vector<uint8_t>* out_bytes);

  /**
   * Creates a non-writing output stream used to calculate the size of
   * the serialized output.
   */
  static Writer Sizing() {
    return Writer(PB_OSTREAM_SIZING);
  }

  /**
   * Writes a message type to the output stream.
   *
   * This essentially wraps calls to nanopb's pb_encode_tag() method.
   */
  void WriteTag(Tag tag);

  void WriteSize(size_t size);
  void WriteNull();
  void WriteBool(bool bool_value);
  void WriteInteger(int64_t integer_value);

  void WriteString(const std::string& string_value);

  /**
   * Writes a message and its length.
   *
   * When writing a top level message, protobuf doesn't include the length
   * (since you can get that already from the length of the binary output.) But
   * when writing a sub/nested message, you must include the length in the
   * serialization.
   *
   * Call this method when writing a nested message. Provide a function to
   * write the message itself. This method will calculate the size of the
   * written message (using the provided function with a non-writing sizing
   * stream), write out the size (and perform sanity checks), and then serialize
   * the message by calling the provided function a second time.
   */
  void WriteNestedMessage(const std::function<void(Writer*)>& write_message_fn);

  size_t bytes_written() const {
    return stream_.bytes_written;
  }

  Status status() const {
    return status_;
  }

 private:
  Status status_ = Status::OK();

  /**
   * Creates a new Writer, based on the given nanopb pb_ostream_t. Note that
   * a shallow copy will be taken. (Non-null pointers within this struct must
   * remain valid for the lifetime of this Writer.)
   */
  explicit Writer(const pb_ostream_t& stream) : stream_(stream) {
  }

  /**
   * Writes a "varint" to the output stream.
   *
   * This essentially wraps calls to nanopb's pb_encode_varint() method.
   *
   * Note that (despite the value parameter type) this works for bool, enum,
   * int32, int64, uint32 and uint64 proto field types.
   *
   * Note: This is not expected to be called directly, but rather only
   * via the other Write* methods (i.e. WriteBool, WriteLong, etc)
   *
   * @param value The value to write, represented as a uint64_t.
   */
  void WriteVarint(uint64_t value);

  pb_ostream_t stream_;
};

/**
 * Docs TODO(rsgowman). But currently, this just wraps the underlying nanopb
 * pb_istream_t.
 */
class Reader {
 public:
  /**
   * Creates an input stream that reads from the specified bytes. Note that
   * this reference must remain valid for the lifetime of this Reader.
   *
   * (This is roughly equivalent to the nanopb function
   * pb_istream_from_buffer())
   *
   * @param bytes where the input should be deserialized from.
   */
  static Reader Wrap(const uint8_t* bytes, size_t length);

  /**
   * Reads a message type from the input stream.
   *
   * This essentially wraps calls to nanopb's pb_decode_tag() method.
   */
  Tag ReadTag();

  void ReadNull();
  bool ReadBool();
  int64_t ReadInteger();

  std::string ReadString();

  /**
   * Reads a message and its length.
   *
   * Analog to Writer::WriteNestedMessage(). See that methods docs for further
   * details.
   *
   * Call this method when reading a nested message. Provide a function to read
   * the message itself.
   */
  template <typename T>
  T ReadNestedMessage(const std::function<T(Reader*)>& read_message_fn);

  size_t bytes_left() const {
    return stream_.bytes_left;
  }

 private:
  /**
   * Creates a new Reader, based on the given nanopb pb_istream_t. Note that
   * a shallow copy will be taken. (Non-null pointers within this struct must
   * remain valid for the lifetime of this Reader.)
   */
  explicit Reader(pb_istream_t stream) : stream_(stream) {
  }

  /**
   * Reads a "varint" from the input stream.
   *
   * This essentially wraps calls to nanopb's pb_decode_varint() method.
   *
   * Note that (despite the return type) this works for bool, enum, int32,
   * int64, uint32 and uint64 proto field types.
   *
   * Note: This is not expected to be called direclty, but rather only via the
   * other Decode* methods (i.e. DecodeBool, DecodeLong, etc)
   *
   * @return The decoded varint as a uint64_t.
   */
  uint64_t ReadVarint();

  pb_istream_t stream_;
};

Writer Writer::Wrap(std::vector<uint8_t>* out_bytes) {
  // TODO(rsgowman): find a better home for this constant.
  // A document is defined to have a max size of 1MiB - 4 bytes.
  static const size_t kMaxDocumentSize = 1 * 1024 * 1024 - 4;

  // Construct a nanopb output stream.
  //
  // Set the max_size to be the max document size (as an upper bound; one would
  // expect individual FieldValue's to be smaller than this).
  //
  // bytes_written is (always) initialized to 0. (NB: nanopb does not know or
  // care about the underlying output vector, so where we are in the vector
  // itself is irrelevant. i.e. don't use out_bytes->size())
  pb_ostream_t raw_stream = {
      /*callback=*/[](pb_ostream_t* stream, const pb_byte_t* buf,
                      size_t count) -> bool {
        auto* out_bytes = static_cast<std::vector<uint8_t>*>(stream->state);
        out_bytes->insert(out_bytes->end(), buf, buf + count);
        return true;
      },
      /*state=*/out_bytes,
      /*max_size=*/kMaxDocumentSize,
      /*bytes_written=*/0,
      /*errmsg=*/nullptr};
  return Writer(raw_stream);
}

Reader Reader::Wrap(const uint8_t* bytes, size_t length) {
  return Reader{pb_istream_from_buffer(bytes, length)};
}

// TODO(rsgowman): I've left the methods as near as possible to where they were
// before, which implies that the Writer methods are interspersed with the
// Reader methods. This should make it a bit easier to review. Refactor these to
// group the related methods together (probably within their own file rather
// than here).

void Writer::WriteTag(Tag tag) {
  if (!status_.ok()) return;

  if (!pb_encode_tag(&stream_, tag.wire_type, tag.field_number)) {
    FIREBASE_ASSERT_MESSAGE(false, PB_GET_ERROR(&stream_));
  }
}

Tag Reader::ReadTag() {
  Tag tag;
  bool eof;
  bool ok = pb_decode_tag(&stream_, &tag.wire_type, &tag.field_number, &eof);
  if (!ok || eof) {
    // TODO(rsgowman): figure out error handling
    abort();
  }
  return tag;
}

void Writer::WriteSize(size_t size) {
  return WriteVarint(size);
}

void Writer::WriteVarint(uint64_t value) {
  if (!status_.ok()) return;

  if (!pb_encode_varint(&stream_, value)) {
    FIREBASE_ASSERT_MESSAGE(false, PB_GET_ERROR(&stream_));
  }
}

/**
 * Note that (despite the return type) this works for bool, enum, int32, int64,
 * uint32 and uint64 proto field types.
 *
 * Note: This is not expected to be called directly, but rather only via the
 * other Decode* methods (i.e. DecodeBool, DecodeLong, etc)
 *
 * @return The decoded varint as a uint64_t.
 */
uint64_t Reader::ReadVarint() {
  uint64_t varint_value;
  if (!pb_decode_varint(&stream_, &varint_value)) {
    // TODO(rsgowman): figure out error handling
    abort();
  }
  return varint_value;
}

void Writer::WriteNull() {
  return WriteVarint(google_protobuf_NullValue_NULL_VALUE);
}

void Reader::ReadNull() {
  uint64_t varint = ReadVarint();
  if (varint != google_protobuf_NullValue_NULL_VALUE) {
    // TODO(rsgowman): figure out error handling
    abort();
  }
}

void Writer::WriteBool(bool bool_value) {
  return WriteVarint(bool_value);
}

bool Reader::ReadBool() {
  uint64_t varint = ReadVarint();
  switch (varint) {
    case 0:
      return false;
    case 1:
      return true;
    default:
      // TODO(rsgowman): figure out error handling
      abort();
  }
}

void Writer::WriteInteger(int64_t integer_value) {
  return WriteVarint(integer_value);
}

int64_t Reader::ReadInteger() {
  return ReadVarint();
}

void Writer::WriteString(const std::string& string_value) {
  if (!status_.ok()) return;

  if (!pb_encode_string(
          &stream_, reinterpret_cast<const pb_byte_t*>(string_value.c_str()),
          string_value.length())) {
    FIREBASE_ASSERT_MESSAGE(false, PB_GET_ERROR(&stream_));
  }
}

std::string Reader::ReadString() {
  pb_istream_t substream;
  if (!pb_make_string_substream(&stream_, &substream)) {
    // TODO(rsgowman): figure out error handling
    abort();
  }

  std::string result(substream.bytes_left, '\0');
  if (!pb_read(&substream, reinterpret_cast<pb_byte_t*>(&result[0]),
               substream.bytes_left)) {
    // TODO(rsgowman): figure out error handling
    abort();
  }

  // NB: future versions of nanopb read the remaining characters out of the
  // substream (and return false if that fails) as an additional safety
  // check within pb_close_string_substream. Unfortunately, that's not present
  // in the current version (0.38).  We'll make a stronger assertion and check
  // to make sure there *are* no remaining characters in the substream.
  if (substream.bytes_left != 0) {
    // TODO(rsgowman): figure out error handling
    abort();
  }

  pb_close_string_substream(&stream_, &substream);

  return result;
}

// Named '..Impl' so as to not conflict with Serializer::EncodeFieldValue.
// TODO(rsgowman): Refactor to use a helper class that wraps the stream struct.
// This will help with error handling, and should eliminate the issue of two
// 'EncodeFieldValue' methods.
void EncodeFieldValueImpl(Writer* writer, const FieldValue& field_value) {
  // TODO(rsgowman): some refactoring is in order... but will wait until after a
  // non-varint, non-fixed-size (i.e. string) type is present before doing so.
  switch (field_value.type()) {
    case FieldValue::Type::Null:
      writer->WriteTag(
          {PB_WT_VARINT, google_firestore_v1beta1_Value_null_value_tag});
      writer->WriteNull();
      break;

    case FieldValue::Type::Boolean:
      writer->WriteTag(
          {PB_WT_VARINT, google_firestore_v1beta1_Value_boolean_value_tag});
      writer->WriteBool(field_value.boolean_value());
      break;

    case FieldValue::Type::Integer:
      writer->WriteTag(
          {PB_WT_VARINT, google_firestore_v1beta1_Value_integer_value_tag});
      writer->WriteInteger(field_value.integer_value());
      break;

    case FieldValue::Type::String:
      writer->WriteTag(
          {PB_WT_STRING, google_firestore_v1beta1_Value_string_value_tag});
      writer->WriteString(field_value.string_value());
      break;

    case FieldValue::Type::Object:
      writer->WriteTag(
          {PB_WT_STRING, google_firestore_v1beta1_Value_map_value_tag});
      EncodeObject(writer, field_value.object_value());
      break;

    default:
      // TODO(rsgowman): implement the other types
      abort();
  }
}

FieldValue DecodeFieldValueImpl(Reader* reader) {
  Tag tag = reader->ReadTag();

  // Ensure the tag matches the wire type
  // TODO(rsgowman): figure out error handling
  switch (tag.field_number) {
    case google_firestore_v1beta1_Value_null_value_tag:
    case google_firestore_v1beta1_Value_boolean_value_tag:
    case google_firestore_v1beta1_Value_integer_value_tag:
      if (tag.wire_type != PB_WT_VARINT) {
        abort();
      }
      break;

    case google_firestore_v1beta1_Value_string_value_tag:
    case google_firestore_v1beta1_Value_map_value_tag:
      if (tag.wire_type != PB_WT_STRING) {
        abort();
      }
      break;

    default:
      abort();
  }

  switch (tag.field_number) {
    case google_firestore_v1beta1_Value_null_value_tag:
      reader->ReadNull();
      return FieldValue::NullValue();
    case google_firestore_v1beta1_Value_boolean_value_tag:
      return FieldValue::BooleanValue(reader->ReadBool());
    case google_firestore_v1beta1_Value_integer_value_tag:
      return FieldValue::IntegerValue(reader->ReadInteger());
    case google_firestore_v1beta1_Value_string_value_tag:
      return FieldValue::StringValue(reader->ReadString());
    case google_firestore_v1beta1_Value_map_value_tag:
      return FieldValue::ObjectValueFromMap(
          DecodeObject(reader).internal_value);

    default:
      // TODO(rsgowman): figure out error handling
      abort();
  }
}

void Writer::WriteNestedMessage(
    const std::function<void(Writer*)>& write_message_fn) {
  if (!status_.ok()) return;

  // First calculate the message size using a non-writing substream.
  Writer sizer = Writer::Sizing();
  write_message_fn(&sizer);
  status_ = sizer.status();
  if (!status_.ok()) return;
  size_t size = sizer.bytes_written();

  // Write out the size to the output writer.
  WriteSize(size);
  if (!status_.ok()) return;

  // If this stream is itself a sizing stream, then we don't need to actually
  // parse field_value a second time; just update the bytes_written via a call
  // to pb_write. (If we try to write the contents into a sizing stream, it'll
  // fail since sizing streams don't actually have any buffer space.)
  if (stream_.callback == nullptr) {
    if (!pb_write(&stream_, nullptr, size)) {
      FIREBASE_ASSERT_MESSAGE(false, PB_GET_ERROR(&stream_));
    }
    return;
  }

  // Ensure the output stream has enough space
  if (stream_.bytes_written + size > stream_.max_size) {
    FIREBASE_ASSERT_MESSAGE(
        false,
        "Insufficient space in the output stream to write the given message");
  }

  // Use a substream to verify that a callback doesn't write more than what it
  // did the first time. (Use an initializer rather than setting fields
  // individually like nanopb does. This gives us a *chance* of noticing if
  // nanopb adds new fields.)
  Writer writer({stream_.callback, stream_.state,
                 /*max_size=*/size, /*bytes_written=*/0,
                 /*errmsg=*/nullptr});
  write_message_fn(&writer);
  status_ = writer.status();
  if (!status_.ok()) return;

  stream_.bytes_written += writer.stream_.bytes_written;
  stream_.state = writer.stream_.state;
  stream_.errmsg = writer.stream_.errmsg;

  if (writer.bytes_written() != size) {
    // submsg size changed
    FIREBASE_ASSERT_MESSAGE(
        false, "Parsing the nested message twice yielded different sizes");
  }
}

template <typename T>
T Reader::ReadNestedMessage(const std::function<T(Reader*)>& read_message_fn) {
  // Implementation note: This is roughly modeled on pb_decode_delimited,
  // adjusted to account for the oneof in FieldValue.
  pb_istream_t raw_substream;
  if (!pb_make_string_substream(&stream_, &raw_substream)) {
    // TODO(rsgowman): figure out error handling
    abort();
  }
  Reader substream(raw_substream);

  T message = read_message_fn(&substream);

  // NB: future versions of nanopb read the remaining characters out of the
  // substream (and return false if that fails) as an additional safety
  // check within pb_close_string_substream. Unfortunately, that's not present
  // in the current version (0.38).  We'll make a stronger assertion and check
  // to make sure there *are* no remaining characters in the substream.
  if (substream.bytes_left() != 0) {
    // TODO(rsgowman): figure out error handling
    abort();
  }
  pb_close_string_substream(&stream_, &substream.stream_);

  return message;
}

/**
 * Encodes a 'FieldsEntry' object, within a FieldValue's map_value type.
 *
 * In protobuf, maps are implemented as a repeated set of key/values. For
 * instance, this:
 *   message Foo {
 *     map<string, Value> fields = 1;
 *   }
 * would be written (in proto text format) as:
 *   {
 *     fields: {key:"key string 1", value:{<Value message here>}}
 *     fields: {key:"key string 2", value:{<Value message here>}}
 *     ...
 *   }
 *
 * This method writes an individual entry from that list. It is expected that
 * this method will be called once for each entry in the map.
 *
 * @param kv The individual key/value pair to write.
 */
void EncodeFieldsEntry(Writer* writer, const ObjectValue::Map::value_type& kv) {
  // Write the key (string)
  writer->WriteTag(
      {PB_WT_STRING, google_firestore_v1beta1_MapValue_FieldsEntry_key_tag});
  writer->WriteString(kv.first);

  // Write the value (FieldValue)
  writer->WriteTag(
      {PB_WT_STRING, google_firestore_v1beta1_MapValue_FieldsEntry_value_tag});
  writer->WriteNestedMessage(
      [&kv](Writer* writer) { EncodeFieldValueImpl(writer, kv.second); });
}

ObjectValue::Map::value_type DecodeFieldsEntry(Reader* reader) {
  Tag tag = reader->ReadTag();

  // TODO(rsgowman): figure out error handling: We can do better than a failed
  // assertion.
  FIREBASE_ASSERT(tag.field_number ==
                  google_firestore_v1beta1_MapValue_FieldsEntry_key_tag);
  FIREBASE_ASSERT(tag.wire_type == PB_WT_STRING);
  std::string key = reader->ReadString();

  tag = reader->ReadTag();
  FIREBASE_ASSERT(tag.field_number ==
                  google_firestore_v1beta1_MapValue_FieldsEntry_value_tag);
  FIREBASE_ASSERT(tag.wire_type == PB_WT_STRING);

  FieldValue value =
      reader->ReadNestedMessage<FieldValue>(DecodeFieldValueImpl);

  return {key, value};
}

void EncodeObject(Writer* writer, const ObjectValue& object_value) {
  return writer->WriteNestedMessage([&object_value](Writer* writer) {
    // Write each FieldsEntry (i.e. key-value pair.)
    for (const auto& kv : object_value.internal_value) {
      writer->WriteTag({PB_WT_STRING,
                        google_firestore_v1beta1_MapValue_FieldsEntry_key_tag});
      writer->WriteNestedMessage(
          [&kv](Writer* writer) { return EncodeFieldsEntry(writer, kv); });
    }
  });
}

ObjectValue DecodeObject(Reader* reader) {
  ObjectValue::Map internal_value = reader->ReadNestedMessage<ObjectValue::Map>(
      [](Reader* reader) -> ObjectValue::Map {
        ObjectValue::Map result;
        while (reader->bytes_left()) {
          Tag tag = reader->ReadTag();
          FIREBASE_ASSERT(tag.field_number ==
                          google_firestore_v1beta1_MapValue_fields_tag);
          FIREBASE_ASSERT(tag.wire_type == PB_WT_STRING);

          ObjectValue::Map::value_type fv =
              reader->ReadNestedMessage<ObjectValue::Map::value_type>(
                  DecodeFieldsEntry);

          // Sanity check: ensure that this key doesn't already exist in the
          // map.
          // TODO(rsgowman): figure out error handling: We can do better than a
          // failed assertion.
          FIREBASE_ASSERT(result.find(fv.first) == result.end());

          // Add this key,fieldvalue to the results map.
          result.emplace(std::move(fv));
        }
        return result;
      });
  return ObjectValue{internal_value};
}

}  // namespace

Status Serializer::EncodeFieldValue(const FieldValue& field_value,
                                    std::vector<uint8_t>* out_bytes) {
  Writer writer = Writer::Wrap(out_bytes);
  EncodeFieldValueImpl(&writer, field_value);
  return writer.status();
}

FieldValue Serializer::DecodeFieldValue(const uint8_t* bytes, size_t length) {
  Reader reader = Reader::Wrap(bytes, length);
  return DecodeFieldValueImpl(&reader);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
