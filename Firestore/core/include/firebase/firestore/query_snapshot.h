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

#ifndef FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_QUERY_SNAPSHOT_H_
#define FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_QUERY_SNAPSHOT_H_

namespace firebase {
namespace firestore {

/**
 * A QuerySnapshot contains zero or more DocumentSnapshot objects. It can be
 * iterated using a range-based for loop and its size can be inspected with
 * empty() and count().
 */
// TODO(zxu123): add more methods to complete the class and make it useful.
class QuerySnapshot {};

}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_QUERY_SNAPSHOT_H_
