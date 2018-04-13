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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_IMMUTABLE_SORTED_MAP_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_IMMUTABLE_SORTED_MAP_H_

#include <utility>

#include "Firestore/core/src/firebase/firestore/immutable/array_sorted_map.h"
#include "Firestore/core/src/firebase/firestore/immutable/sorted_map_base.h"
#include "Firestore/core/src/firebase/firestore/immutable/tree_sorted_map.h"
#include "Firestore/core/src/firebase/firestore/util/comparison.h"

namespace firebase {
namespace firestore {
namespace immutable {

/**
 * SortedMap is a value type containing a map. It is immutable, but
 * has methods to efficiently create new maps that are mutations of it.
 */
template <typename K, typename V, typename C = util::Comparator<K>>
class SortedMap : public impl::SortedMapBase {
 public:
  /** The type of the entries stored in the map. */
  using value_type = std::pair<K, V>;
  using array_type = impl::ArraySortedMap<K, V, C>;
  using tree_type = impl::TreeSortedMap<K, V, C>;

  /**
   * Creates an empty SortedMap.
   */
  explicit SortedMap(const C& comparator = {})
      : SortedMap{array_type{comparator}} {
  }

  /**
   * Creates an SortedMap containing the given entries.
   */
  SortedMap(std::initializer_list<value_type> entries,
            const C& comparator = {}) {
    if (entries.size() <= kFixedSize) {
      tag_ = Tag::Array;
      new (&array_) array_type{entries, comparator};
    } else {
      // TODO(wilhuff): implement tree initialization
      abort();
    }
  }

  SortedMap(const SortedMap& other) : tag_{other.tag_} {
    switch (tag_) {
      case Tag::Array:
        new (&array_) array_type{other.array_};
        break;
      case Tag::Tree:
        new (&tree_) tree_type{other.tree_};
        break;
    }
  }

  SortedMap(SortedMap&& other) : tag_{other.tag_} {
    switch (tag_) {
      case Tag::Array:
        new (&array_) array_type{std::move(other.array_)};
        break;
      case Tag::Tree:
        new (&tree_) tree_type{std::move(other.tree_)};
        break;
    }
  }

  ~SortedMap() {
    switch (tag_) {
      case Tag::Array:
        array_.~ArraySortedMap();
        break;
      case Tag::Tree:
        tree_.~TreeSortedMap();
        break;
    }
  }

  SortedMap& operator=(const SortedMap& other) {
    if (tag_ == other.tag_) {
      switch (tag_) {
        case Tag::Array:
          array_ = other.array_;
          break;
        case Tag::Tree:
          tree_ = other.tree_;
          break;
      }
    } else {
      this->~SortedMap();
      new (this) SortedMap{other};
    }
    return *this;
  }

  SortedMap& operator=(SortedMap&& other) {
    if (tag_ == other.tag_) {
      switch (tag_) {
        case Tag::Array:
          array_ = std::move(other.array_);
          break;
        case Tag::Tree:
          tree_ = std::move(other.tree_);
          break;
      }
    } else {
      this->~SortedMap();
      new (this) SortedMap{std::move(other)};
    }
    return *this;
  }

  /**
   * Creates a new map identical to this one, but with a key-value pair added or
   * updated.
   *
   * @param key The key to insert/update.
   * @param value The value to associate with the key.
   * @return A new dictionary with the added/updated value.
   */
  SortedMap insert(const K& key, const V& value) const {
    switch (tag_) {
      case Tag::Array:
        // TODO(wilhuff): convert to TreeSortedMap
        return SortedMap{array_.insert(key, value)};
      case Tag::Tree:
        return SortedMap{tree_.insert(key, value)};
    }
    FIREBASE_UNREACHABLE();
  }

  /**
   * Creates a new map identical to this one, but with a key removed from it.
   *
   * @param key The key to remove.
   * @return A new map without that value.
   */
  SortedMap erase(const K& key) const {
    switch (tag_) {
      case Tag::Array:
        return SortedMap{array_.erase(key)};
      case Tag::Tree:
        return SortedMap{tree_.erase(key)};
    }
    FIREBASE_UNREACHABLE();
  }

  /** Returns true if the map contains no elements. */
  bool empty() const {
    switch (tag_) {
      case Tag::Array:
        return array_.empty();
      case Tag::Tree:
        return tree_.empty();
    }
    FIREBASE_UNREACHABLE();
  }

  /** Returns the number of items in this map. */
  size_type size() const {
    switch (tag_) {
      case Tag::Array:
        return array_.size();
      case Tag::Tree:
        return tree_.size();
    }
    FIREBASE_UNREACHABLE();
  }

 private:
  explicit SortedMap(array_type&& array)
      : tag_{Tag::Array}, array_{std::move(array)} {
  }

  explicit SortedMap(tree_type&& tree)
      : tag_{Tag::Tree}, tree_{std::move(tree)} {
  }

  enum class Tag {
    Array,
    Tree,
  };

  Tag tag_;
  union {
    array_type array_;
    tree_type tree_;
  };
};

}  // namespace immutable
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_IMMUTABLE_SORTED_MAP_H_
