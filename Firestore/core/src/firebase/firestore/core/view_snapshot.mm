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

#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"

#import "Firestore/Source/Model/FSTDocument.h"

#include "Firestore/core/src/firebase/firestore/util/objc_compatibility.h"
#include "Firestore/core/src/firebase/firestore/util/string_format.h"

namespace firebase {
namespace firestore {
namespace core {

namespace objc = util::objc;
using util::MakeString;
using util::StringFormat;

std::string DocumentViewChange::ToString() const {
  std::string doc_description = MakeString([document() description]);
  return StringFormat("<DocumentViewChange type:%s doc:%s>", type(),
                      doc_description);
}

bool DocumentViewChange::operator==(const DocumentViewChange& rhs) const {
  return objc::Equals(document_, rhs.document_) && type_ == rhs.type_;
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
