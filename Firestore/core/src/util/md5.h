/*
 * Copyright 2023 Google LLC
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

#ifndef FIRESTORE_CORE_SRC_UTIL_MD5_H_
#define FIRESTORE_CORE_SRC_UTIL_MD5_H_

#include <array>
#include <memory>

#include "Firestore/core/src/util/config.h"

#if HAVE_OPENSSL_MD5_H
#include "openssl/md5.h"
#else
#error "No MD5 implementation is available"
#endif

namespace firebase {
namespace firestore {
namespace util {

class Md5 final {
 public:
  Md5();
  ~Md5() = default;

  // Copyable and movable
  Md5(const Md5&);
  Md5& operator=(const Md5&);
  Md5(Md5&&) noexcept;
  Md5& operator=(Md5&&) noexcept;

  /**
   * Resets the internal state to its newly-constructed state.
   *
   * Invoke this method if it is desired to calculate a new digest after this
   * object has already been used to calculate another digest.
   */
  void Reset();

  /**
   * Consumes the given data and updates the digest calculated so far.
   * @param data the data to consume.
   * @param len the length of the given data to consume.
   */
  void Update(const void* data, int len);

  /**
   * Returns the calculated digest based on previous calls to Update().
   */
  std::array<unsigned char, 16> Digest();

 private:
#if HAVE_OPENSSL_MD5_H
  MD5_CTX ctx_;
#endif
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_UTIL_MD5_H_
