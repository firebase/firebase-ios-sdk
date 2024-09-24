/**
 * @license
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef FIRESTORE_CORE_SRC_LOCAL_GLOBALS_CACHE_H_
#define FIRESTORE_CORE_SRC_LOCAL_GLOBALS_CACHE_H_

#include "Firestore/core/src/nanopb/byte_string.h"

using firebase::firestore::nanopb::ByteString;

namespace firebase {
namespace firestore {
namespace local {

/**
 * General purpose cache for global values.
 *
 * Global state that cuts across components should be saved here. Following are
 * contained herein:
 *
 * `sessionToken` tracks server interaction across Listen and Write streams.
 * This facilitates cache synchronization and invalidation.
 */
class GlobalsCache {
 public:
  virtual ~GlobalsCache() = default;

  /**
   * Gets session token.
   */
  virtual ByteString GetSessionToken() const = 0;

  /**
   * Sets session token.
   */
  virtual void SetSessionToken(const ByteString& session_token) = 0;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_LOCAL_GLOBALS_CACHE_H_
