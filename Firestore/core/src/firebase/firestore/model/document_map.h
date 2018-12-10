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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_DOCUMENT_MAP_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_DOCUMENT_MAP_H_

#include <utility>

#import "Firestore/Source/Model/FSTDocument.h"

#include "Firestore/core/src/firebase/firestore/immutable/sorted_map.h"
#include "Firestore/core/src/firebase/firestore/immutable/sorted_map_iterator.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"

#include "absl/base/attributes.h"

namespace firebase {
namespace firestore {
namespace model {

/**
 * Convenience type for a map of keys to MaybeDocuments, since they are so
 * common.
 */
using MaybeDocumentMap = immutable::SortedMap<DocumentKey, FSTMaybeDocument*>;

/**
 * Convenience type for a map of keys to Documents, since they are so common.
 *
 * PORTING NOTE: unlike other platforms, in C++ `Foo<Derived*>` cannot be
 * converted to `Foo<Base*>`; consequently, if `DocumentMap` were simply an
 * alias similar to `MaybeDocumentMap`, it couldn't be passed to functions
 * expecting `MaybeDocumentMap`.
 *
 * To work around this, in C++ `DocumentMap` is a simple wrapper over
 * a `MaybeDocumentMap` that forwards all functions to the underlying map but
 * with added type safety (it only accepts `FSTDocument`s, not
 * `FSTMaybeDocument`s). Use `DocumentMap` in functions creating and/or
 * returning maps that only contain `FSTDocument`s; when the `DocumentMap` needs
 * to be passed to a function accepting a `MaybeDocumentMap`, use
 * `underlying_map` function to get (read-only) access to the representation.
 */
class DocumentMap {
 public:
   // Wraps `MaybeDocumentMap::const_iterator`, providing necessary conversions
   // from `FSTMaybeDocument*` to `FSTDocument*`.
  class const_iterator {
   public:
    using iterator_category =
        MaybeDocumentMap::const_iterator::iterator_category;
    using value_type = std::pair<DocumentKey, FSTDocument*>;
    using pointer = const value_type*;
    using reference = const value_type&;
    using difference_type = MaybeDocumentMap::const_iterator::difference_type;

    const_iterator() = default;

    pointer get() const {
      UpdateCurrentValue();
      return &current_value_;
    }
    reference operator*() const {
      UpdateCurrentValue();
      return current_value_;
    }
    pointer operator->() const {
      return get();
    }

    const_iterator& operator++() {
      ++iter_;
      return *this;
    }
    const_iterator operator++(int /*unused*/) {
      const_iterator old_value = *this;
      ++iter_;
      return old_value;
    }

    friend bool operator==(const const_iterator& a, const const_iterator& b) {
      return a.iter_ == b.iter_;
    }
    friend bool operator!=(const const_iterator& a, const const_iterator& b) {
      return a.iter_ != b.iter_;
    }

   private:
    friend class DocumentMap;

    explicit const_iterator(MaybeDocumentMap::const_iterator&& iter)
        : iter_{iter} {
    }

    // Iterator cannot use the value of the underlying iterator because the
    // types are unrelated and one cannot be cast to the other. Also, the value
    // cannot be created on the fly, otherwise `get` and `operator->` would
    // return a pointer to a stale temporary. As a result, the value has be
    // stored as a data member.
    //
    // The problem is when to update the value. Value cannot be updated in
    // constructor or during iteration, because the underlying iterator might be
    // one-past-end at that point. Consequently, value has to be updated upon
    // access. It's a tradeoff whether to only update the value if it changed
    // or unconditionally. Here it is done unconditionally, on the assumption
    // that each particular value usually doesn't get more than one or two
    // accesses.
    void UpdateCurrentValue() const {
      const std::pair<DocumentKey, FSTMaybeDocument*>& underlying_value =
          *iter_;
      current_value_ =
          value_type{underlying_value.first,
                     static_cast<FSTDocument*>(underlying_value.second)};
    }

    MaybeDocumentMap::const_iterator iter_;
    // To mimic the underlying iterator, functions returning the value or
    // a pointer to value are const, but they still have to update the
    // `current_value_`.
    mutable value_type current_value_;
  };

  DocumentMap() = default;

  const_iterator begin() const {
    return const_iterator{map_.begin()};
  }
  const_iterator end() const {
    return const_iterator{map_.end()};
  }

  const_iterator find(const DocumentKey& key) const {
    return const_iterator{map_.find(key)};
  }

  ABSL_MUST_USE_RESULT DocumentMap insert(const DocumentKey& key,
                                          FSTDocument* value) const {
    return DocumentMap{map_.insert(key, value)};
  }

  ABSL_MUST_USE_RESULT DocumentMap erase(const DocumentKey& key) const {
    return DocumentMap{map_.erase(key)};
  }

  bool empty() const {
    return map_.empty();
  }
  MaybeDocumentMap::size_type size() const {
    return map_.size();
  }

  /** Use this function to "convert" `DocumentMap` to a `MaybeDocumentMap`. */
  const MaybeDocumentMap& underlying_map() const {
    return map_;
  }

 private:
  explicit DocumentMap(MaybeDocumentMap&& map) : map_{std::move(map)} {
  }

  MaybeDocumentMap map_;
};

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_DOCUMENT_MAP_H_
