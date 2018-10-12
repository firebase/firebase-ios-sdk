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

#if !defined(_STLPORT_VERSION)
#include <initializer_list>
#endif  // !defined(_STLPORT_VERSION)

namespace firebase {
namespace firestore {

namespace model {
class FieldPath;
}  // namespace model

/**
 * A FieldPath refers to a field in a document. The path may consist of a single
 * field name (referring to a top level field in the document), or a list of
 * field names (referring to a nested field in the document).
 */
class FieldPath {
 public:
  using FieldPathInternal = ::firebase::firestore::model::FieldPath;

  /**
   * Default constructor. This creates an invalid FieldPath. Attempting to
   * perform any operations on this path will fail (and cause a crash) unless a
   * valid FieldPath has been assigned to it.
   */
  FieldPath();

#if !defined(_STLPORT_VERSION)
  /**
   * Creates a FieldPath from the provided field names. If more than one field
   * name is provided, the path will point to a nested field in a document.
   *
   * @param field_names A list of field names.
   */
  FieldPath(std::initializer_list<std::string> field_names);
#endif  // !defined(_STLPORT_VERSION)

  /**
   * Copy constructor.
   */
  FieldPath(const FieldPath& path);

  /**
   * Move constructor.
   */
  FieldPath(FieldPath&& path);

  virtual ~FieldPath();

  /**
   * Copy assignment operator.
   */
  FieldPath& operator=(const FieldPath& path);

  /**
   * Move assignment operator.
   */
  FieldPath& operator=(FieldPath&& path);

  /**
   * A special sentinel FieldPath to refer to the ID of a document. It can be
   * used in queries to sort or filter by the document ID.
   */
  static FieldPath DocumentId();

  /**
   * Parses a field path string into a FieldPath, treating dots as separators.
   *
   * @param path Presented as a dot-separated string.
   * @return The created FieldPath.
   */
  static FieldPath FromDotSeparatedString(const std::string& path);

  /**
   * Returns a string representation of this FieldPath.
   */
  virtual std::string ToString() const;

 protected:
  explicit FieldPath(FieldPathInternal* internal);

 private:
  friend bool operator==(const FieldPath& lhs, const FieldPath& rhs);
  friend bool operator!=(const FieldPath& lhs, const FieldPath& rhs);
  friend bool operator<(const FieldPath& lhs, const FieldPath& rhs);
  friend bool operator>(const FieldPath& lhs, const FieldPath& rhs);
  friend bool operator<=(const FieldPath& lhs, const FieldPath& rhs);
  friend bool operator>=(const FieldPath& lhs, const FieldPath& rhs);

  friend class Query;
  friend class QueryInternal;
  friend class FieldPathConverter;

  FieldPathInternal* internal_ = nullptr;
};

}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_FIELD_PATH_H_
