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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_IMMUTABLE_LLRB_NODE_ITERATOR_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_IMMUTABLE_LLRB_NODE_ITERATOR_H_

#include <iterator>
#include <stack>
#include <utility>

#include "Firestore/core/src/firebase/firestore/immutable/llrb_node.h"
#include "Firestore/core/src/firebase/firestore/util/comparison.h"
#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"

namespace firebase {
namespace firestore {
namespace immutable {
namespace impl {

/**
 * An iterator for traversing LlrbNodes.
 *
 * LlrbNode is an immutable tree, where insertions create new trees without
 * invalidating any of the old instances. This means the tree cannot contain
 * parent pointers and thus this iterator implementation must keep an explicit
 * stack.
 */
template <typename N>
class LlrbNodeIterator {
 public:
  using node_type = N;
  using key_type = typename node_type::first_type;

  using stack_type = std::stack<const node_type*>;

  using iterator_category = std::forward_iterator_tag;
  using value_type = typename node_type::value_type;

  using pointer = typename node_type::value_type const*;
  using reference = typename node_type::value_type const&;
  using difference_type = std::ptrdiff_t;

  /**
   * Constructs an iterator starting at the first node in the iteration
   * sequence of the tree represented by the given root node (i.e. it points at
   * the left-most node).
   */
  static LlrbNodeIterator Begin(const node_type* root) {
    stack_type stack;

    const node_type* node = root;
    while (!node->empty()) {
      stack.push(node);
      node = &node->left();
    }

    return LlrbNodeIterator{std::move(stack)};
  }

  /**
   * Constructs an iterator pointing at the end of the iteration sequence of the
   * tree pointed to by the given node (i.e. one past the right-most node)
   */
  static LlrbNodeIterator End() {
    return LlrbNodeIterator{stack_type{}};
  }

  /**
   * Returns true if this iterator points at the end of the iteration sequence.
   */
  bool end() const {
    return stack_.empty();
  }

  /**
   * Returns the address of the entry in the node that this iterator points to.
   * This can only be called if `end()` is false.
   */
  pointer get() const {
    FIREBASE_ASSERT(!end());
    return &(stack_.top()->entry());
  }

  reference operator*() const {
    return *get();
  }

  pointer operator->() const {
    return get();
  }

  LlrbNodeIterator& operator++() {
    if (end()) {
      return *this;
    }

    // Pop the stack, moving the currently pointed to node to the parent.
    const node_type* node = stack_.top();
    stack_.pop();

    // If the popped node has a right subtree that has to precede the parent in
    // the iteration order so push those on.
    node = &node->right();
    while (!node->empty()) {
      stack_.push(node);
      node = &node->left();
    }

    return *this;
  }

  LlrbNodeIterator operator++(int /*unused*/) {
    LlrbNodeIterator result = *this;
    ++*this;
    return result;
  }

  friend bool operator==(const LlrbNodeIterator& a, const LlrbNodeIterator& b) {
    if (a.end()) {
      return b.end();
    } else if (b.end()) {
      return false;
    } else {
      const key_type& left_key = a.get()->first;
      const key_type& right_key = b.get()->first;
      return left_key == right_key;
    }
  }

  bool operator!=(LlrbNodeIterator b) const {
    return !(*this == b);
  }

 private:
  explicit LlrbNodeIterator(stack_type&& stack) : stack_(std::move(stack)) {
  }

  stack_type stack_;
};

}  // namespace impl
}  // namespace immutable
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_IMMUTABLE_LLRB_NODE_ITERATOR_H_
