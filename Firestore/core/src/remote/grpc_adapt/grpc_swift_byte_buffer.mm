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

#include "Firestore/core/src/util/string_apple.h"

namespace firebase {
namespace firestore {
namespace remote {
namespace grpc_adapt {

using firebase::firestore::util::MakeNSString;

class SliceImpl {
 public:
  explicit SliceImpl(SliceShim* shim) : shim_(shim) {
  }
  SliceShim* shim() {
    return shim_;
  }

 private:
  SliceShim* shim_;
};

Slice::Slice(const std::string& s) {
  impl_ = new SliceImpl([[SliceShim alloc] initWithStr:MakeNSString(s)]);
}

Slice::Slice(const uint8_t* begin, size_t size) {
  impl_ = new SliceImpl([[SliceShim alloc]
      initWithBuf:reinterpret_cast<const int8_t*>(begin)
              len:size]);
}

size_t Slice::size() const {
  return [impl_->shim() size];
}
const uint8_t* Slice::begin() const {
  return reinterpret_cast<uint8_t*>([impl_->shim() begin]);
}

class ByteBufferImpl : public ByteBuffer {
 public:
  explicit ByteBufferImpl(ByteBufferShim* shim) : shim_(shim) {
  }
  ByteBufferShim* shim() {
    return shim_;
  }

 private:
  ByteBufferShim* shim_;
};

ByteBuffer::ByteBuffer() {
  ByteBufferShim* shim = [[ByteBufferShim alloc] init];
  impl_ = new ByteBufferImpl(shim);
}

ByteBuffer::ByteBuffer(const Slice* slices, size_t nslices) {
  ByteBufferShim* shim = [[ByteBufferShim alloc] init];
  for (int i = 0; i < nslices; i++) {
    [shim addWithBegin:slices[i].begin() size:slices[i].size()];
  }
  impl_ = new ByteBufferImpl(shim);
}

size_t ByteBuffer::Length() const {
  return [impl_->shim() Length];
}

Status ByteBuffer::Dump(std::vector<Slice>* slices) const {
  NSMutableArray<SliceShim*>* sliceShims = [[NSMutableArray alloc] init];
  for (Slice slice : *slices) {
    [sliceShims addObject:slice.impl_->shim()];
  }
  [impl_->shim() DumpWithSlices:sliceShims];
  return Status();
}

}  // namespace grpc_adapt
}  // namespace remote
}  // namespace firestore
}  // namespace firebase
