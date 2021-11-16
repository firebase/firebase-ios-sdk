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
#include "Firestore/core/src/remote/grpc_adapt/grpc_swift_byte_buffer.h"

#import "GRPCSwiftShim/GRPCSwiftShim-Swift.h"

#include <Foundation/Foundation.h>
#include "Firestore/core/src/remote/grpc_adapt/grpc_swift_slice.h"

namespace firebase {
namespace firestore {
namespace remote {
namespace grpc_adapt {

ByteBuffer::ByteBuffer() {
  shim_ = [ByteBufferShim new];
}

ByteBuffer::ByteBuffer(const Slice* slices, size_t nslices) {
  shim_ = [ByteBufferShim new];
  std::vector<Slice> slice_vector{slices, nslices};
  Dump(*slice_vector);
}

size_t ByteBuffer::Length() const {
  return shim_.Length;
}

Status ByteBuffer::Dump(std::vector<Slice>* slices) const {
  std::vector<Slice> unwrapped_slices;
  for (Slice slice : *slices) {
    unwrapped_slices.push_back(slice.shim);
  }
  return shim_.Dump(unwrapped_slices);
}

}  // namespace grpc_adapt
}  // namespace remote
}  // namespace firestore
}  // namespace firebase
