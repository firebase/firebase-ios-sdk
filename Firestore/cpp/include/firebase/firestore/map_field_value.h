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

#include <string>
#include <unordered_map>

#ifndef FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_MAP_FIELD_VALUE_H_
#define FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_MAP_FIELD_VALUE_H_

namespace firebase {
namespace firestore {

class FieldValue;

#ifdef STLPORT
using MapFieldValue = std::tr1::unordered_map<std::string, FieldValue>;
#else
using MapFieldValue = std::unordered_map<std::string, FieldValue>;
#endif

}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_MAP_FIELD_VALUE_H_
