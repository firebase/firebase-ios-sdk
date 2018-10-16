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

#include "Firestore/core/include/firebase/firestore/field_path.h"

#include <algorithm>

#include "Firestore/core/src/firebase/firestore/model/field_path.h"

namespace firebase {
namespace firestore {

FieldPath::FieldPath() {
}

#if !defined(_STLPORT_VERSION)
FieldPath::FieldPath(std::initializer_list<std::string> field_names)
    : internal_(new FieldPathInternal{field_names}) {
}
#endif  // !defined(_STLPORT_VERSION)

FieldPath::FieldPath(const FieldPath& path)
    : internal_(new FieldPathInternal{*path.internal_}) {
}

FieldPath::FieldPath(FieldPath&& path) : internal_(path.internal_) {
  path.internal_ = nullptr;
}

FieldPath::FieldPath(FieldPathInternal* internal) : internal_(internal) {
}

FieldPath::~FieldPath() {
  delete internal_;
  internal_ = nullptr;
}

FieldPath& FieldPath::operator=(const FieldPath& path) {
  if (this == &path) {
    return *this;
  }

  delete internal_;
  internal_ = new FieldPathInternal{*path.internal_};
  return *this;
}

FieldPath& FieldPath::operator=(FieldPath&& path) {
  std::swap(internal_, path.internal_);
  return *this;
}

/* static */
FieldPath FieldPath::DocumentId() {
  return FieldPath{new FieldPathInternal{FieldPathInternal::KeyFieldPath()}};
}

/* static */
FieldPath FieldPath::FromDotSeparatedString(const std::string& path) {
  return FieldPath{
      new FieldPathInternal{FieldPathInternal::FromServerFormat(path)}};
}

std::string FieldPath::ToString() const {
  return internal_->CanonicalString();
}

bool operator==(const FieldPath& lhs, const FieldPath& rhs) {
  return *lhs.internal_ == *rhs.internal_;
}

bool operator!=(const FieldPath& lhs, const FieldPath& rhs) {
  return *lhs.internal_ != *rhs.internal_;
}

bool operator<(const FieldPath& lhs, const FieldPath& rhs) {
  return *lhs.internal_ < *rhs.internal_;
}

bool operator>(const FieldPath& lhs, const FieldPath& rhs) {
  return *lhs.internal_ > *rhs.internal_;
}

bool operator<=(const FieldPath& lhs, const FieldPath& rhs) {
  return *lhs.internal_ <= *rhs.internal_;
}

bool operator>=(const FieldPath& lhs, const FieldPath& rhs) {
  return *lhs.internal_ >= *rhs.internal_;
}

}  // namespace firestore
}  // namespace firebase
