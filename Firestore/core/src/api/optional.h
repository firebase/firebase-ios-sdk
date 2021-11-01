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

#ifndef FIRESTORE_CORE_SRC_API_OPTIONAL_H_
#define FIRESTORE_CORE_SRC_API_OPTIONAL_H_

// This file is copied from
// https://github.com/firebase/firebase-cpp-sdk/blob/58dbf86c8b767b90f8427275388f6309617650fa/app/src/optional.h
// with local modifications

#include <cassert>
#include <cstdint>
#include <new>
#include <utility>

#include "Firestore/core/src/api/common.h"

namespace firebase {
namespace firestore {
namespace api {

struct nullopt_t {
  struct init {};
  explicit nullopt_t(init) {
  }
};

const nullopt_t nullopt((nullopt_t::init()));

// optional<T> is a utility class to represent a value that can, but does not
// have to be present.
//
// This has a few different use cases. For return values, it allows values to be
// optionally returned without using pointers that might be null. In other
// words, a function that returns a pointer might always return a valid pointer,
// or it might sometimes return a valid pointer and sometimes return null.
// Returning an optional makes it clear what the intention is.
//
// The other main use case is to be able to defer initialization of a value on
// the stack or in a struct. By using an optional you can leave a value
// uninitialized at creation and later initialize it when appropriate without
// having to default construct a value, or keep a null pointer to a value and
// later initializing it.
template <typename T>
class Optional {
 public:
  typedef T value_type;

  // Initialize an empty optional.
  Optional() : has_value_(false) {
  }

  // Copy contructor. If the other optional has a value, it is copied into this
  // optional using its copy constructor.
  Optional(const Optional& other) : has_value_(other.has_value()) {
    if (other.has_value()) {
      new (aligned_buffer()) value_type(other.value());
    }
  }

  // Copy assignment. If the other optional has a value, it is copy constructed
  // or copy assigned into this optional.
  Optional& operator=(const Optional& other) {
    if (other.has_value()) {
      *this = other.value();
    } else {
      reset();
    }
    return *this;
  }

#if defined(FIREBASE_USE_MOVE_OPERATORS)
  // Move contructor. If the other optional has a value, it is moved into this
  // optional using its move constructor.
  Optional(Optional&& other) noexcept : has_value_(other.has_value_) {
    if (has_value()) {
      new (aligned_buffer()) value_type(std::move(other.value()));
      other.reset();
    }
  }

  // Move assignment. If the other optional has a value, it is move constructed
  // or move assigned into this optional.
  Optional& operator=(Optional&& other) noexcept {
    if (other.has_value()) {
      *this = std::move(other.value());
    } else {
      reset();
    }
    other.reset();
    return *this;
  }
#endif  // FIREBASE_USE_MOVE_OPERATORS

  // Initialize this optional with the given value.
  explicit Optional(const value_type& initial_value) : has_value_(true) {
    new (aligned_buffer()) value_type(initial_value);
  }

  // Set value directly via copy constructor.
  Optional& operator=(const value_type& other) {
    if (has_value()) {
      value() = other;
    } else {
      new (aligned_buffer()) value_type(other);
    }
    has_value_ = true;
    return *this;
  }

#if defined(FIREBASE_USE_MOVE_OPERATORS)
  // Move construction with a given value.
  explicit Optional(value_type&& initial_value) : has_value_(true) {
    new (aligned_buffer()) value_type(std::move(initial_value));
  }

  // Set value directly via move constructor.
  Optional& operator=(value_type&& other) {
    if (has_value()) {
      value() = std::move(other);
    } else {
      new (aligned_buffer()) value_type(std::move(other));
    }
    has_value_ = true;
    return *this;
  }
#endif  // FIREBASE_USE_MOVE_OPERATORS

  ~Optional() {
    reset();
  }

  // Structure reference operator, to allow access to the members of the object
  // held by the optional.
  const value_type* operator->() const {
    return &value();
  }
  value_type* operator->() {
    return &value();
  }

  // Dereference operator, to allow access to the members of the object held by
  // the optional.
  const value_type& operator*() const {
    return value();
  }
  value_type& operator*() {
    return value();
  }

  // Returns true if this value contains a value, false otherwise.
  bool has_value() const {
    return has_value_;
  }

  // Returns the value held. Value must be present.
  const value_type& value() const {
    assert(has_value());
    return *aligned_buffer();
  }

  // Returns the value held. Value must be present.
  value_type& value() {
    assert(has_value());
    return *aligned_buffer();
  }

  // Returns the value held, or if empty, the default value provided.
  value_type value_or(const value_type& default_value) const {
    if (has_value()) {
      return value();
    } else {
      return default_value;
    }
  }

  // If this optional contains a value, destruct it and mark this optional as
  // empty.
  void reset() {
    if (has_value()) {
      value().~value_type();
      has_value_ = false;
    }
  }

  operator bool() const {
    return has_value();
  }

 private:
  const T* aligned_buffer() const {
    return reinterpret_cast<const T*>(&buffer_);
  }
  T* aligned_buffer() {
    return reinterpret_cast<T*>(&buffer_);
  }

  // Older versions of Visual Studio (2013 and prior) do not have support
  // for alignof, but do have __alignof, so map it to use that if necessary.
#if (defined(_MSC_VER) && _MSC_VER <= 1800)
#define FIREBASE_ALIGNOF __alignof
#else
#define FIREBASE_ALIGNOF alignof
#endif  // (defined(_MSC_VER) && _MSC_VER <= 1800)

  typename FIREBASE_ALIGNED_STORAGE<sizeof(T), FIREBASE_ALIGNOF(T)>::type
      buffer_;

#undef FIREBASE_ALIGNOF

  bool has_value_;
};

template <typename T>
Optional<T> optionalFromPointer(const T* pointer) {
  return pointer ? Optional<T>(*pointer) : Optional<T>();
}

template <typename T>
bool operator==(const Optional<T>& lhs, const Optional<T>& rhs) {
  return lhs.has_value() == rhs.has_value() &&
         (!lhs.has_value() || (lhs.value() == rhs.value()));
}

template <typename T>
bool operator!=(const Optional<T>& lhs, const Optional<T>& rhs) {
  return !(lhs == rhs);
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_API_OPTIONAL_H_
