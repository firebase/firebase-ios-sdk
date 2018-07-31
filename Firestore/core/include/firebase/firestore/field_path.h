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

#ifndef FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_FIELD_PATH_H_
#define FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_FIELD_PATH_H_

#include <string>

namespace firebase {
namespace firestore {

class FieldPathInternal;

/**
 * A FieldPath refers to a field in a document. The path may consist of a single
 * field name (referring to a top level field in the document), or a list of
 * field names (referring to a nested field in the document).
 */
// TODO(zxu123): add more methods to complete the class and make it useful.
class FieldPath {
 private:
  /**
   * Parses a field path string into a FieldPath, treating dots as separators.
   *
   * @param path Presented as a dot-separated string.
   * @return The created FieldPath.
   */
  static FieldPath FromDotSeparatedString(const std::string& path);

  friend class Query;
  friend class QueryInternal;

  FieldPathInternal* internal_ = nullptr;
};

}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_FIELD_PATH_H_
