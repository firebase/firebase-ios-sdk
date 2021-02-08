/*
 * Copyright 2021 Google LLC
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

#ifndef FIRESTORE_CORE_SRC_UTIL_RANDOM_ACCESS_QUEUE_H_
#define FIRESTORE_CORE_SRC_UTIL_RANDOM_ACCESS_QUEUE_H_

#include <deque>
#include <unordered_map>
#include <string>
#include <vector>

namespace firebase {
namespace firestore {
namespace util {

/**
 * A queue that provides efficient removal of arbitrary elements.
 *
 * Another way to think of this class is an `unordered_set` that preserves
 * insertion order and provides efficient access to the "front" element and
 * removal of arbitrary elements.
 *
 * This class is implemented by maintaining two data structures: a queue that
 * keeps track of insertion order and a set that provides efficient lookup.
 * As a result, this class consumes roughly twice as much memory as a plain old
 * queue and each mutating operation is roughly twice as slow as a plain old
 * queue since each mutation must be performed on two data structures. However,
 * these costs come at the benefit of being able to test for queue membership in
 * constant time and remove queue elements in amortized constant time.
 *
 * The template argument `T` is the type of the elements to store in the queue.
 * The remainin variadic template arguments are passed as the template arguments
 * to `unordered_map`, allowing custom hashing and comparison functions to be
 * specified.
 */
template <typename T, typename... UnorderedMapArgs>
class RandomAccessQueue {
 public:

  /**
   * Adds an element to the back of this queue, if it is not already present.
   *
   * Returns `true` if the given element was *not* already present in this
   * queue, and therefore was added to the back, or `false` if the given element
   * *was* already present in this queue, and therefore no changes were made to
   * this object.
   *
   * This method has average constant-time complexity.
   */
  bool push_back(const T& element) {
    // Put the key into the map if it is not already present. The `nullptr` will
    // be replaced by a pointer to the object added to the queue when it is
    // added below.
    auto map_emplace_result = queue_entries_by_key_.emplace(element, nullptr);

    // Return `false` and do nothing if the given element was already present.
    if (!map_emplace_result.second) {
      return false;
    }

    // Add the element to the queue and update the pointer in the map.
    queue_.emplace_back(element);
    map_emplace_result.first->second = &queue_.back();

    // Return `true` to indicate that the element was added to the queue.
    return true;
  }

  /**
   * Returns the element at the front of the queue.
   *
   * The behavior of this method is undefined if the queue is empty.
   *
   * This method has constant-time complexity.
   */
  const T& front() const {
    return queue_.front().element();
  }

  /**
   * Removes the element at the front of the queue.
   *
   * The behavior of this method is undefined if the queue is empty.
   *
   * This method has average constant-time complexity; however, it is O(n) in
   * the worst case, which occurs when popping the last element.
   */
  void pop_front() {
    const T& front_element = queue_.front().element();
    queue_entries_by_key_.erase(front_element);
    queue_.pop_front();
    PruneLeadingQueueEntries();
  }

  /**
   * Removes the given element from the queue, if it is present.
   *
   * Returns `true` if the given element was found in the queue and removed, or
   * `false` if the given element was *not* found in the queue and therefore no
   * changes were made to this object.
   *
   * This method has average constant-time complexity; however, it is O(n) in
   * the worst case, which occurs when popping the last element.
   */
  bool remove(const T& element) {
    auto it = queue_entries_by_key_.find(element);
    if (it == queue_entries_by_key_.end()) {
      return false;
    }
    it->second->set_removed();
    queue_entries_by_key_.erase(it);
    PruneLeadingQueueEntries();
    return true;
  }

  /**
   * Returns whether or not this queue is empty.
   *
   * This method has constant-time complexity.
   */
  bool empty() const {
    return queue_.empty();
  }

  /**
   * Returns whether or not this queue contains the given element.
   *
   * This method has average constant-time complexity.
   */
  bool contains(const T& element) const {
    return queue_entries_by_key_.find(element) != queue_entries_by_key_.end();
  }

  /**
   * Returns the keys in the queue.
   *
   * The order of the keys in the returned `vector` is the insertion order of
   * those keys in this queue.
   */
  std::vector<T> keys() const {
    std::vector<T> keys;
    for (const QueueEntry& entry : queue_) {
      if (!entry.removed()) {
        keys.push_back(entry.element());
      }
    }
    return keys;
  }

 private:
  class QueueEntry {
   public:
    explicit QueueEntry(const T& element) : element_(element) {}
    const T& element() const { return element_; }
    bool removed() const { return removed_; }
    void set_removed() { removed_ = true; }
   private:
    T element_;
    bool removed_ = false;
  };

  /**
   * Removes all "removed" queue entries from the front of the queue.
   *
   * This method is useful to maintain the invariant that the front of the queue
   * *must* be an element whose `removed()` method returns `false`.
   */
  void PruneLeadingQueueEntries() {
    while (!queue_.empty() && queue_.front().removed()) {
      queue_entries_by_key_.erase(queue_.front().element());
      queue_.pop_front();
    }
  }

  /**
   * The queued elements.
   *
   * When an element is "removed" from the queue, then instead of actually
   * removing it, which is an O(n) operation, the "removed" flag of the
   * corresponding queue entry is set to `true`; then, when that entry
   * eventually makes its way to the front of the queue, it will be discarded
   * and ignored.
   *
   * The front entry of the queue *must* always be one whose `removed` flag is
   * `false`. This allows the `front()` method to be implemented as a mere
   * pass-through to the `front()` method of this object.
   */
  std::deque<QueueEntry> queue_;

  /**
   * Maps the non-removed elements to their queue entry in `queue_`.
   *
   * Note: Since `std::deque` preserves pointer stability, the values in this
   * map are pointers directly into `queue_`; therefore, care must be taken to
   * not use the values after they have been removed from `queue_`.
   */
  std::unordered_map<T, QueueEntry*, UnorderedMapArgs...> queue_entries_by_key_;
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_UTIL_RANDOM_ACCESS_QUEUE_H_

