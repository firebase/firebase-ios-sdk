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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_IMMUTABLE_TREE_SORTED_MAP_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_IMMUTABLE_TREE_SORTED_MAP_H_

#include <assert.h>

#include <algorithm>
#include <functional>
#include <memory>
#include <utility>

#include "Firestore/core/src/firebase/firestore/immutable/llrb_node.h"
#include "Firestore/core/src/firebase/firestore/immutable/map_entry.h"
#include "Firestore/core/src/firebase/firestore/immutable/sorted_map_base.h"
#include "Firestore/core/src/firebase/firestore/util/comparator_holder.h"
#include "Firestore/core/src/firebase/firestore/util/comparison.h"
#include "Firestore/core/src/firebase/firestore/util/iterator_adaptors.h"

namespace firebase {
namespace firestore {
namespace immutable {
namespace impl {

/**
 * TreeSortedMap is a value type containing a map. It is immutable, but has
 * methods to efficiently create new maps that are mutations of it.
 */
template <typename K, typename V, typename C = util::Comparator<K>>
class TreeSortedMap : public SortedMapBase, private util::ComparatorHolder<C> {
 public:
  /**
   * The type of the entries stored in the map.
   */
  using value_type = std::pair<K, V>;

  /**
   * The type of the node containing entries of value_type.
   */
  using node_type = LlrbNode<K, V>;

  /**
   * Creates an empty TreeSortedMap.
   */
  explicit TreeSortedMap(const C& comparator = {})
      : util::ComparatorHolder<C>{comparator}, root_{node_type::Empty()} {
  }

  /**
   * Creates a new map identical to this one, but with a key-value pair added or
   * updated.
   *
   * @param key The key to insert/update.
   * @param value The value to associate with the key.
   * @return A new dictionary with the added/updated value.
   */
  TreeSortedMap insert(const K& key, const V& value) const {
    // TODO(wilhuff): Actually implement insert
    (void)key;
    (void)value;
    return *this;
  }

  /**
   * Creates a new map identical to this one, but with a key removed from it.
   *
   * @param key The key to remove.
   * @return A new map without that value.
   */
  TreeSortedMap erase(const K& key) const {
    // TODO(wilhuff): Actually implement erase
    (void)key;
    return *this;
  }

  /** Returns true if the map contains no elements. */
  bool empty() const {
    return root_.empty();
  }

  /** Returns the number of items in this map. */
  size_type size() const {
    return root_.size();
  }

  const node_type& root() const {
    return root_;
  }

 private:
  TreeSortedMap(node_type&& root, const C& comparator) noexcept
      : util::ComparatorHolder<C>{comparator}, root_{std::move(root)} {
  }

  TreeSortedMap Wrap(node_type&& root) noexcept {
    return TreeSortedMap{std::move(root), this->comparator()};
  }

  node_type root_;
};

}  // namespace impl
}  // namespace immutable
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_IMMUTABLE_TREE_SORTED_MAP_H_
