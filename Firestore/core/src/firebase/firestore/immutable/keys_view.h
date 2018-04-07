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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_IMMUTABLE_KEYS_VIEW_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_IMMUTABLE_KEYS_VIEW_H_

#include "Firestore/core/src/firebase/firestore/util/iterator_adaptors.h"
#include "Firestore/core/src/firebase/firestore/util/range.h"

namespace firebase {
namespace firestore {
namespace immutable {
namespace impl {

/**
 * Returns of a view of the given range containing just the first par that have
 * been inserted.
 */
template <typename Range>
auto KeysView(const Range& range)
    -> util::range<util::iterator_first<decltype(std::begin(range))>> {
  auto keys_begin = util::make_iterator_first(std::begin(range));
  auto keys_end = util::make_iterator_first(std::end(range));
  return util::make_range(keys_begin, keys_end);
}

}  // namespace impl
}  // namespace immutable
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_IMMUTABLE_KEYS_VIEW_H_
