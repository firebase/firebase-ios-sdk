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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_IMMUTABLE_LLRB_NODE_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_IMMUTABLE_LLRB_NODE_H_

#include <memory>
#include <utility>

#include "Firestore/core/src/firebase/firestore/immutable/sorted_map_base.h"

namespace firebase {
namespace firestore {
namespace immutable {
namespace impl {

/**
 * A Color of a tree node in a red-black tree.
 */
enum Color : unsigned int {
  Black,
  Red,
};

/**
 * LlrbNode is a node in a TreeSortedMap.
 */
template <typename K, typename V>
class LlrbNode : public SortedMapBase {
 public:
  using first_type = K;
  using second_type = V;

  /**
   * The type of the entries stored in the map.
   */
  using value_type = std::pair<K, V>;

  /**
   * Constructs an empty node.
   */
  LlrbNode() : LlrbNode{EmptyRep()} {
  }

  /** Returns the number of elements at this node or beneath it in the tree. */
  size_type size() const {
    return rep_->size_;
  }

  /** Returns true if this is an empty node--a leaf node in the tree. */
  bool empty() const {
    return size() == 0;
  }

  /** Returns true if this node is red (as opposed to black). */
  bool red() const {
    return static_cast<bool>(rep_->color_);
  }

  const value_type& entry() const {
    return rep_->entry_;
  }
  const K& key() const {
    return entry().first;
  }
  const V& value() const {
    return entry().second;
  }
  Color color() const {
    return static_cast<Color>(rep_->color_);
  }
  const LlrbNode& left() const {
    return rep_->left_;
  }
  const LlrbNode& right() const {
    return rep_->right_;
  }

 private:
  struct Rep {
    Rep(value_type&& entry,
        size_type color,
        size_type size,
        LlrbNode left,
        LlrbNode right)
        : entry_{std::move(entry)},
          color_{color},
          size_{size},
          left_{std::move(left)},
          right_{std::move(right)} {
    }

    value_type entry_;

    // Store the color in the high bit of the size to save memory.
    size_type color_ : 1;
    size_type size_ : 31;

    LlrbNode left_;
    LlrbNode right_;
  };

  explicit LlrbNode(const std::shared_ptr<Rep>& rep) : rep_{rep} {
  }

  explicit LlrbNode(std::shared_ptr<Rep>&& rep) : rep_{std::move(rep)} {
  }

  /**
   * Returns a shared Empty node, to cut down on allocations in the base case.
   */
  static const std::shared_ptr<Rep>& EmptyRep() {
    static const std::shared_ptr<Rep> empty_rep = [] {
      auto empty = std::make_shared<Rep>(Rep{std::pair<K, V>{}, Color::Black,
                                             /* size= */ 0u, LlrbNode{nullptr},
                                             LlrbNode{nullptr}});

      // Set up the empty Rep such that you can traverse infinitely down left
      // and right links.
      empty->left_.rep_ = empty;
      empty->right_.rep_ = empty;
      return empty;
    }();
    return empty_rep;
  }

  std::shared_ptr<Rep> rep_;
};

}  // namespace impl
}  // namespace immutable
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_IMMUTABLE_LLRB_NODE_H_
