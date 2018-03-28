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
  // TODO(wilhuff): move this into NodeData if that structure is to live on.
  LlrbNode()
      : LlrbNode{NodeData{{},
                          Color::Black,
                          /*size=*/0u,
                          LlrbNode{nullptr},
                          LlrbNode{nullptr}}} {
  }

  /**
   * Returns a shared Empty node, to cut down on allocations in the base case.
   */
  static const LlrbNode& Empty() {
    static const LlrbNode empty_node{};
    return empty_node;
  }

  /** Returns the number of elements at this node or beneath it in the tree. */
  size_type size() const {
    return data_->size_;
  }

  /** Returns true if this is an empty node--a leaf node in the tree. */
  bool empty() const {
    return size() == 0;
  }

  /** Returns true if this node is red (as opposed to black). */
  bool red() const {
    return static_cast<bool>(data_->red_);
  }

  const value_type& entry() const {
    return data_->contents_;
  }
  const K& key() const {
    return entry().first;
  }
  const V& value() const {
    return entry().second;
  }
  Color color() const {
    return data_->red_ ? Color::Red : Color::Black;
  }
  const LlrbNode& left() const {
    return data_->left_;
  }
  const LlrbNode& right() const {
    return data_->right_;
  }

 private:
  struct NodeData {
    value_type contents_;

    // Store the color in the high bit of the size to save memory.
    size_type red_ : 1;
    size_type size_ : 31;

    LlrbNode left_;
    LlrbNode right_;
  };

  explicit LlrbNode(NodeData&& data)
      : data_{std::make_shared<NodeData>(std::move(data))} {
  }

  /**
   * Constructs a dummy node that's a child of the empty node. This exists so
   * that every node can have non-optional left and right children, despite the
   * fact that these don't actually get visited.
   *
   * This should only be called when constructing the empty node.
   */
  explicit LlrbNode(std::nullptr_t) : data_{nullptr} {
  }

  std::shared_ptr<NodeData> data_;
};

}  // namespace impl
}  // namespace immutable
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_IMMUTABLE_LLRB_NODE_H_
