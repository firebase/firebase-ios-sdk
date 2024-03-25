/*
 * Copyright 2024 Google
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

#ifndef FIRESTORE_CORE_SRC_API_LISTEN_SOURCE_H_
#define FIRESTORE_CORE_SRC_API_LISTEN_SOURCE_H_

namespace firebase {
namespace firestore {
namespace api {

/**
 * An enum that configures the snapshot listener data source. Using this enum,
 * specify whether snapshot events are triggered by local cache changes
 * only, or from both local cache and watch changes(which is the default).
 *
 * See `FIRFirestoreListenSource` for more details.
 */
enum class ListenSource { Default, Cache };

}  // namespace api
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_API_LISTEN_SOURCE_H_
