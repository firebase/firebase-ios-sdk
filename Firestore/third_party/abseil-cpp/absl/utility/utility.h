// Copyright 2017 The Abseil Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// This header file contains C++11 versions of standard <utility> header
// abstractions available within C++14 and C++17, and are designed to be drop-in
// replacement for code compliant with C++14 and C++17.
//
// The following abstractions are defined:
//
//   * integer_sequence<T, Ints...>  == std::integer_sequence<T, Ints...>
//   * index_sequence<Ints...>       == std::index_sequence<Ints...>
//   * make_integer_sequence<T, N>   == std::make_integer_sequence<T, N>
//   * make_index_sequence<N>        == std::make_index_sequence<N>
//   * index_sequence_for<Ts...>     == std::index_sequence_for<Ts...>
//   * apply<Functor, Tuple>         == std::apply<Functor, Tuple>
//
// This header file also provides the tag types `in_place_t`, `in_place_type_t`,
// and `in_place_index_t`, as well as the constant `in_place`, and
// `constexpr` `std::move()` and `std::forward()` implementations in C++11.
//
// References:
//
//  http://en.cppreference.com/w/cpp/utility/integer_sequence
//  http://en.cppreference.com/w/cpp/utility/apply
//  http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2013/n3658.html
//

#ifndef ABSL_UTILITY_UTILITY_H_
#define ABSL_UTILITY_UTILITY_H_

#include <cstddef>
#include <cstdlib>
#include <tuple>
#include <utility>

#include "absl/base/config.h"
#include "absl/base/internal/inline_variable.h"
#include "absl/meta/type_traits.h"

namespace absl {

// Tag types

#ifdef ABSL_HAVE_STD_OPTIONAL

using std::in_place_t;
using std::in_place;

#else  // ABSL_HAVE_STD_OPTIONAL

// in_place_t
//
// Tag type used to specify in-place construction, such as with
// `absl::optional`, designed to be a drop-in replacement for C++17's
// `std::in_place_t`.
struct in_place_t {};

ABSL_INTERNAL_INLINE_CONSTEXPR(in_place_t, in_place, {});

#endif  // ABSL_HAVE_STD_OPTIONAL

// Constexpr move and forward

// move()
//
// A constexpr version of `std::move()`, designed to be a drop-in replacement
// for C++14's `std::move()`.
template <typename T>
constexpr absl::remove_reference_t<T>&& move(T&& t) noexcept {
  return static_cast<absl::remove_reference_t<T>&&>(t);
}

// forward()
//
// A constexpr version of `std::forward()`, designed to be a drop-in replacement
// for C++14's `std::forward()`.
template <typename T>
constexpr T&& forward(
    absl::remove_reference_t<T>& t) noexcept {  // NOLINT(runtime/references)
  return static_cast<T&&>(t);
}

}  // namespace absl

#endif  // ABSL_UTILITY_UTILITY_H_
