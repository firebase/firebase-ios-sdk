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

#include "Firestore/core/src/firebase/firestore/nanopb/message.h"

#include <cstdint>
#include <vector>

#include "Firestore/core/src/firebase/firestore/nanopb/writer.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_util.h"

namespace firebase {
namespace firestore {

using remote::ConvertStatus;
using util::Status;
using util::StatusOr;

namespace nanopb {

namespace internal {

StatusOr<ByteString> ToByteString(const grpc::ByteBuffer& buffer) {
  std::vector<grpc::Slice> slices;
  grpc::Status status = buffer.Dump(&slices);
  // Conversion may fail if compression is used and gRPC tries to decompress an
  // ill-formed buffer.
  if (!status.ok()) {
    Status error{Error::Internal,
                 "Trying to convert an invalid grpc::ByteBuffer"};
    error.CausedBy(ConvertStatus(status));
    return error;
  }

  ByteStringWriter writer;
  writer.Reserve(buffer.Length());
  for (const auto& slice : slices) {
    writer.Append(slice.begin(), slice.size());
  }

  return writer.Release();
}

}  // namespace internal

void FreeNanopbMessage(const pb_field_t* fields, void* dest_struct) {
  pb_release(fields, dest_struct);
}

}  // namespace nanopb
}  // namespace firestore
}  // namespace firebase
