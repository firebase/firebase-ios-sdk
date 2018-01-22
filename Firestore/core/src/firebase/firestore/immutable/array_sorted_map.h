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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_IMMUTABLE_ARRAY_SORTED_MAP_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_IMMUTABLE_ARRAY_SORTED_MAP_H_

#include <assert.h>

#include <algorithm>
#include <array>
#include <functional>
#include <memory>
#include <utility>

#include "Firestore/core/src/firebase/firestore/immutable/map_entry.h"

namespace firebase {
namespace firestore {
namespace immutable {

/**
 * A base class for implementing ArraySortedMap, which contains constants and
 * types that don't depend upon the type of ArraySortedMap's type parameters.
 */
class ArraySortedMapBase {
 public:
  /**
   * The type of size(). Note that this is not size_t specifically to save
   * space in the TreeSortedMap implementation.
   */
  typedef uint32_t size_type;

  /**
   * The maximum size of an ArraySortedMap.
   *
   * This is the size threshold where we use a tree backed sorted map instead
   * of an array backed sorted map. This is a more or less arbitrary chosen
   * value, that was chosen to be large enough to fit most of object kind of
   * Firebase data, but small enough to not notice degradation in performance
   * for inserting and lookups. Feel free to empirically determine this
   * constant, but don't expect much gain in real world performance.
   */
  static constexpr size_type kFixedSize = 25;
};

/**
 * A thin wrapper around std::array that also maintains a dynamic size.
 *
 * ArraySortedMap does not actually contain its array: it contains a
 * shared_ptr to a FixedArray
 *
 * @tparam T The contents of an element in the array.
 * @tparam fixed_size the fixed size to use in creating the FixedArray.
 */
template <typename T, ArraySortedMapBase::size_type fixed_size>
class FixedArray {
 public:
  typedef ArraySortedMapBase::size_type size_type;
  typedef std::array<T, fixed_size> array_type;
  typedef typename array_type::iterator iterator;
  typedef typename array_type::const_iterator const_iterator;

  /**
   * Appends to this array, copying from the given src_begin up to but not
   * including the src_end.
   */
  template <typename SourceIterator>
  void append(SourceIterator src_begin, SourceIterator src_end) {
    auto copy_end = std::copy(src_begin, src_end, end());
    size_ = static_cast<size_type>(copy_end - begin());
  }

  /**
   * Appends a single value to the array.
   */
  void append(T&& value) {
    *end() = std::forward<T>(value);
    size_ += 1;
  }

  iterator begin() {
    return contents_.begin();
  }

  const_iterator begin() const {
    return contents_.begin();
  }

  iterator end() {
    return begin() + size_;
  }

  const_iterator end() const {
    return begin() + size_;
  }

 private:
  array_type contents_;
  size_type size_;

  template <typename K, typename V, typename C>
  friend class ArraySortedMap;
};

/**
 * ArraySortedMap is a value type containing a map. It is immutable, but has
 * methods to efficiently create new maps that are mutations of it.
 */
template <typename K, typename V, typename C = std::less<K>>
class ArraySortedMap : public ArraySortedMapBase {
 public:
  typedef ArraySortedMap<K, V, C> this_type;
  typedef KeyComparator<K, V, C> key_comparator_type;

  /**
   * The type of the entries stored in the map.
   */
  typedef std::pair<K, V> value_type;

  /**
   * The type of the fixed-size array containing entries of value_type.
   */
  typedef FixedArray<value_type, kFixedSize> array_type;
  typedef typename array_type::const_iterator const_iterator;

  typedef std::shared_ptr<const array_type> array_pointer;

  /**
   * Creates an empty ArraySortedMap.
   */
  explicit ArraySortedMap(const C& comparator = C())
      : array_(EmptyArray()), key_comparator_(comparator) {
  }

  /**
   * Creates an ArraySortedMap containing the given entries.
   */
  explicit ArraySortedMap(std::initializer_list<value_type> entries,
                          const C& comparator = C())
      : array_(), key_comparator_(comparator) {
    assert(static_cast<size_type>(entries.size()) <= kFixedSize);

    auto array = std::make_shared<array_type>();
    array->append(entries.begin(), entries.end());
    array_ = array;
  }

  /**
   * Creates a new map identical to this one, but with a key-value pair added or
   * updated.
   *
   * @param key The key to insert/update.
   * @param value The value to associate with the key.
   * @return A new dictionary with the added/updated value.
   */
  this_type insert(const K& key, const V& value) const {
    value_type pair(key, value);

    const_iterator current_end = end();
    const_iterator pos = LowerBound(pair.first);
    bool replacing_entry = false;

    if (pos != current_end) {
      // LowerBound found an entry where pos->first >= pair.first. Reversing the
      // argument order here tests pair.first < pos->first.
      bool keys_equal = !key_comparator_(pair.first, *pos);
      if (keys_equal) {
        const V& pos_value = pos->second;
        const V& pair_value = pair.second;
        if (pos_value == pair_value) {
          return *this;
        } else {
          replacing_entry = true;
        }
      }
    }

    // Copy the segment before the found position. If not found, this is
    // everything.
    auto copy = std::make_shared<array_type>();
    copy->append(begin(), pos);

    // Copy the value to be inserted.
    copy->append(std::move(pair));

    if (replacing_entry) {
      // Skip the thing at pos because it compares the same as the pair above.
      ++pos;
    } else {
      // If inserting at the end or the key at pos is not equal to what we're
      // inserting, then increase the size.
      assert(size() < kFixedSize);
    }

    // Copy everything after pos (if anything).
    copy->append(pos, current_end);
    return wrap(copy);
  }

  /**
   * Creates a new map identical to this one, but with a key removed from it.
   *
   * @param key The key to remove.
   * @return A new dictionary without that value.
   */
  this_type erase(const K& key) const {
    const_iterator current_end = end();
    const_iterator pos = find(key);
    if (pos == current_end) {
      return *this;
    } else {
      auto copy = std::make_shared<array_type>();
      copy->size_ = size() - 1;
      auto copy_end = std::copy(begin(), pos, copy->begin());
      if (pos + 1 < current_end) {
        std::copy(pos + 1, end(), copy_end);
      }
      return wrap(copy);
    }
  }

  /**
   * Finds a value in the map.
   *
   * @param key The key to look up.
   * @return An iterator pointing to the entry containing the key, or end() if
   *     not found.
   */
  const_iterator find(const K& key) const {
    const_iterator not_found = end();
    const_iterator lower_bound = LowerBound(key);
    if (lower_bound != not_found && !key_comparator_(key, *lower_bound)) {
      return lower_bound;
    } else {
      return not_found;
    }
  }
  // indexof

  /** Returns true if the map contains no elements. */
  bool empty() const {
    return size() == 0;
  }

  /** Returns the number of items in this map. */
  size_type size() const {
    return array_->size_;
  }

  /**
   * Returns an iterator pointing to the first entry in the map. If there are
   * no entries in the map, begin() == end().
   */
  const_iterator begin() const {
    return array_->begin();
  }

  /**
   * Returns an iterator pointing past the last entry in the map.
   */
  const_iterator end() const {
    return array_->end();
  }

 private:
  static array_pointer EmptyArray() {
    static const array_pointer kEmptyArray =
        std::make_shared<const array_type>();
    return kEmptyArray;
  }

  ArraySortedMap(const array_pointer& array,
                 const key_comparator_type& key_comparator) noexcept
      : array_(array), key_comparator_(key_comparator) {
  }

  this_type wrap(const array_pointer& array) const noexcept {
    return this_type(array, key_comparator_);
  }

  const_iterator LowerBound(const K& key) const {
    return std::lower_bound(begin(), end(), key, key_comparator_);
  }

  array_pointer array_;
  key_comparator_type key_comparator_;
};

}  // namespace immutable
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_IMMUTABLE_ARRAY_SORTED_MAP_H_
