/*
 * Copyright 2024 Google LLC
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

#include "Firestore/core/src/local/memory_globals_cache.h"

namespace firebase {
namespace firestore {
namespace local {

ByteString MemoryGlobalsCache::GetSessionToken() const {
  return session_token_;
}

void MemoryGlobalsCache::SetSessionToken(const ByteString& session_token) {
  session_token_ = session_token;
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
