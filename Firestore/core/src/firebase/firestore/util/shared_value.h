/*
 * Copyright 2019 Google
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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_SHARED_VALUE_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_SHARED_VALUE_H_

#include <memory>
#include <type_traits>

#include "absl/meta/type_traits.h"

namespace firebase {
namespace firestore {
namespace util {

/**
 * A smart pointer that implements shared ownership but otherwise with value
 * semantics. That is, operator== compares the thing pointed to, not the pointer
 * itself.
 *
 * Another way to look at this is that it's like std::optional but the
 * underlying value is shared instead of copied.
 */
template <typename T>
class shared_value {
 public:
  using pointer_type = std::shared_ptr<T>;
  using element_type = typename pointer_type::element_type;

  shared_value() = default;

  constexpr shared_value(std::nullptr_t) noexcept : pointer_(nullptr) {
  }

  explicit shared_value(const T& value) : pointer_(std::make_shared<T>(value)) {
  }

  explicit shared_value(T&& value)
      : pointer_(std::make_shared<T>(std::move(value))) {
  }

  template <typename Y,
            typename = absl::enable_if_t<std::is_convertible<Y*, T*>::value>>
  shared_value(const shared_value<Y>& other) : pointer_(other.pointer_) {
  }

  template <typename Y,
            typename = absl::enable_if_t<std::is_convertible<Y*, T*>::value>>
  shared_value(shared_value<Y>&& other) : pointer_(std::move(other.pointer_)) {
  }

  template <typename Y,
            typename = absl::enable_if_t<std::is_convertible<Y*, T*>::value>>
  shared_value(const std::shared_ptr<Y>& pointer) : pointer_(pointer) {
  }

  template <typename Y,
            typename = absl::enable_if_t<std::is_convertible<Y*, T*>::value>>
  shared_value(std::shared_ptr<Y>&& pointer) : pointer_(std::move(pointer)) {
  }

  shared_value& operator=(const T& value) {
    if (pointer_) {
      *pointer_ = value;
    } else {
      pointer_ = std::make_shared<T>(value);
    }
  }

  shared_value& operator=(T&& value) {
    if (pointer_) {
      *pointer_ = std::move(value);
    } else {
      pointer_ = std::make_shared<T>(std::move(value));
    }
  }

  // MARK: Observers

  T* get() const noexcept {
    return pointer_.get();
  }

  T& operator*() const noexcept {
    return *pointer_.get();
  }

  T* operator->() const noexcept {
    return pointer_.get();
  }

  bool has_value() const noexcept {
    return get() != nullptr;
  }

  operator bool() const noexcept {
    return has_value();
  }

  // MARK: Modifiers

  void reset() noexcept {
    pointer_.reset();
  }

 private:
  template <typename Y>
  friend class shared_value;

  pointer_type pointer_;
};

// MARK: Non-members

template <typename T, typename... Args>
shared_value<T> make_shared_value(Args&&... args) {
  static_assert(std::is_constructible<T, Args...>::value,
                "Can't construct object in make_shared_value");
  return shared_value<T>(std::make_shared<T>(std::forward<Args>(args)...));
}

template <typename T>
bool operator==(const shared_value<T>& lhs, const shared_value<T>& rhs) {
  auto left_ptr = lhs.get();
  auto right_ptr = rhs.get();
  return left_ptr == nullptr ? right_ptr == nullptr
                             : right_ptr != nullptr && *left_ptr == *right_ptr;
}

template <typename T>
bool operator!=(const shared_value<T>& lhs, const shared_value<T>& rhs) {
  return !(lhs == rhs);
}

template <typename T>
bool operator==(const shared_value<T>& lhs, std::nullptr_t) {
  return lhs.get() == nullptr;
}

template <typename T>
bool operator!=(const shared_value<T>& lhs, std::nullptr_t) {
  return !(lhs == nullptr);
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_SHARED_VALUE_H_
