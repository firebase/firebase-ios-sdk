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

#include "Firestore/core/src/firebase/firestore/nanopb/reader.h"

#include "Firestore/core/src/firebase/firestore/nanopb/writer.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_util.h"

namespace firebase {
namespace firestore {
namespace nanopb {

using remote::ConvertStatus;
using util::Status;

// Reader

Reader::Reader(const ByteString& bytes) : Reader(bytes.data(), bytes.size()) {
}

Reader::Reader(const std::vector<uint8_t>& bytes)
    : Reader(bytes.data(), bytes.size()) {
}

Reader::Reader(const uint8_t* bytes, size_t size)
    : stream_(pb_istream_from_buffer(bytes, size)) {
}

Reader::Reader(absl::string_view str)
    : Reader(reinterpret_cast<const uint8_t*>(str.data()), str.size()) {
}

void Reader::Read(const pb_field_t fields[], void* dest_struct) {
  if (!status_.ok()) return;

  if (!pb_decode(&stream_, fields, dest_struct)) {
    Fail(PB_GET_ERROR(&stream_));
  }
}

// GrpcByteBufferReader

GrpcByteBufferReader::GrpcByteBufferReader(const grpc::ByteBuffer& buffer) {
  std::vector<grpc::Slice> slices;
  grpc::Status status = buffer.Dump(&slices);
  // Conversion may fail if compression is used and gRPC tries to decompress an
  // ill-formed buffer.
  if (!status.ok()) {
    Status error{Error::Internal,
                 "Trying to convert an invalid grpc::ByteBuffer"};
    error.CausedBy(ConvertStatus(status));
    reader_.set_status(error);
    return;
  }

  ByteStringWriter writer;
  writer.Reserve(buffer.Length());
  for (const auto& slice : slices) {
    writer.Append(slice.begin(), slice.size());
  }

  bytes_ = writer.Release();
  reader_ = Reader{bytes_};
}

}  // namespace nanopb
}  // namespace firestore
}  // namespace firebase
