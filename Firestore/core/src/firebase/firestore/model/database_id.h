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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_DATABASE_ID_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_DATABASE_ID_H_

#include <cstdint>
#include <string>

#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {
namespace model {

/** A DatabaseId represents a particular database in the Firestore. */
class DatabaseId {
 public:
  /** The default name for "unset" database ID in resource names. */
  static constexpr const char* kDefault = "(default)";

#if defined(__OBJC__)
  // For objective-c++ initialization; to be removed after migration.
  // Do NOT use in C++ code.
  DatabaseId() = default;
#endif  // defined(__OBJC__)

  /**
   * Creates and returns a new DatabaseId.
   *
   * @param project_id The project for the database.
   * @param database_id The database in the project to use.
   */
  DatabaseId(absl::string_view project_id, absl::string_view database_id);

  const std::string& project_id() const {
    return project_id_;
  }

  const std::string& database_id() const {
    return database_id_;
  }

  /** Whether this is the default database of the project. */
  bool IsDefaultDatabase() const {
    return database_id_ == kDefault;
  }

#if defined(__OBJC__)
  // For objective-c++ hash; to be removed after migration.
  // Do NOT use in C++ code.
  NSUInteger Hash() const {
    std::hash<std::string> hash_fn;
    return hash_fn(project_id_) * 31u + hash_fn(database_id_);
  }
#endif  // defined(__OBJC__)

  friend bool operator<(const DatabaseId& lhs, const DatabaseId& rhs);

 private:
  std::string project_id_;
  std::string database_id_;
};

/** Compares against another DatabaseId. */
inline bool operator<(const DatabaseId& lhs, const DatabaseId& rhs) {
  return lhs.project_id_ < rhs.project_id_ ||
         (lhs.project_id_ == rhs.project_id_ &&
          lhs.database_id_ < rhs.database_id_);
}

inline bool operator>(const DatabaseId& lhs, const DatabaseId& rhs) {
  return rhs < lhs;
}

inline bool operator>=(const DatabaseId& lhs, const DatabaseId& rhs) {
  return !(lhs < rhs);
}

inline bool operator<=(const DatabaseId& lhs, const DatabaseId& rhs) {
  return !(lhs > rhs);
}

inline bool operator!=(const DatabaseId& lhs, const DatabaseId& rhs) {
  return lhs < rhs || lhs > rhs;
}

inline bool operator==(const DatabaseId& lhs, const DatabaseId& rhs) {
  return !(lhs != rhs);
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_DATABASE_ID_H_
