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

#include "Firestore/core/include/firebase/firestore/blob.h"

#include <stdlib.h>
#include <string.h>

#include <algorithm>

namespace firebase {
namespace firestore {

Blob::Blob() : buffer_(nullptr), size_(0) {
}

Blob::Blob(const Blob& value)
    : buffer_(Blob::CopyFrom(value.Get(), value.size()).Release()),
      size_(value.size()) {
}

Blob::~Blob() {
  free(buffer_);
}

Blob Blob::CopyFrom(const void* source, size_t size) {
  void* copy = malloc(size);
  memcpy(copy, source, size);
  return Blob::MoveFrom(copy, size);
}

Blob Blob::MoveFrom(void* source, size_t size) {
  Blob result;
  result.buffer_ = source;
  result.size_ = size;
  return result;
}

void* Blob::Release() {
  void* result = buffer_;
  buffer_ = nullptr;
  size_ = 0;
  return result;
}

// We have to override the default one or there is ownership issue on the data.
Blob& Blob::operator=(const Blob& value) {
  Blob copy = Blob::CopyFrom(value.Get(), value.size());
  size_ = copy.size();
  buffer_ = copy.Release();
  return *this;
}

// We cannot use C++11 in public header and thus need to provide light-weighted
// equivalent to be used internally e.g. by FieldValue.
void Blob::Swap(Blob& value) {
  std::swap(buffer_, value.buffer_);
  std::swap(size_, value.size_);
}

bool operator<(const Blob& lhs, const Blob& rhs) {
  int comparison =
      memcmp(lhs.Get(), rhs.Get(), std::min(lhs.size(), rhs.size()));
  if (comparison == 0) {
    return lhs.size() < rhs.size();
  } else {
    return comparison < 0;
  }
}

}  // namespace firestore
}  // namespace firebase
