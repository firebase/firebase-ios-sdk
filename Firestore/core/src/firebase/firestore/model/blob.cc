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

#include "Firestore/core/src/firebase/firestore/model/blob.h"

#include <string.h>

#include <algorithm>

namespace firebase {
namespace firestore {
namespace model {

Blob::Blob() : buffer_(nullptr), size_(0) {
}

Blob::Blob(const Blob& value) : Blob() {
  *this = value;
}

Blob::Blob(Blob&& value) : Blob() {
  *this = std::move(value);
}

Blob::~Blob() {
  delete[] buffer_;
}

Blob Blob::CopyFrom(const uint8_t* source, size_t size) {
  uint8_t* copy = new uint8_t[size];
  memcpy(copy, source, size);
  return Blob::MoveFrom(copy, size);
}

Blob Blob::MoveFrom(uint8_t* source, size_t size) {
  Blob result;
  result.buffer_ = source;
  result.size_ = size;
  return result;
}

Blob& Blob::operator=(const Blob& value) {
  Blob copy = CopyFrom(value.buffer_, value.size_);
  return *this = std::move(copy);
}

Blob& Blob::operator=(Blob&& value) {
  std::swap(buffer_, value.buffer_);
  std::swap(size_, value.size_);
  return *this;
}

bool operator<(const Blob& lhs, const Blob& rhs) {
  return std::lexicographical_compare(lhs.begin(), lhs.end(), rhs.begin(),
                                      rhs.end());
}

bool operator==(const Blob& lhs, const Blob& rhs) {
  return lhs.size() == rhs.size() &&
         memcmp(lhs.get(), rhs.get(), lhs.size()) == 0;
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
