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

#include "Firestore/core/src/util/md5.h"

#include "Firestore/core/src/util/config.h"

#if HAVE_OPENSSL_MD5_H

#include "Firestore/core/src/util/hard_assert.h"

#include "openssl/md5.h"

namespace firebase {
namespace firestore {
namespace util {

std::array<unsigned char, 16> CalculateMd5Digest(absl::string_view s) {
  MD5_CTX ctx;

  {
    const int md5_init_result = MD5_Init(&ctx);
    HARD_ASSERT(md5_init_result == 1, "MD5_Init() returned %s, but expected 1",
                md5_init_result);
  }

  {
    int md5_update_result = MD5_Update(&ctx, s.data(), s.length());
    HARD_ASSERT(md5_update_result == 1,
                "MD5_Update() returned %s, but expected 1", md5_update_result);
  }

  {
    std::array<unsigned char, 16> digest;
    int md5_final_result = MD5_Final(digest.data(), &ctx);
    HARD_ASSERT(md5_final_result == 1, "MD5_Final() returned %s but expected 1",
                md5_final_result);
    return digest;
  }
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // HAVE_OPENSSL_MD5_H
