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

#ifndef FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_SET_OPTIONS_H_
#define FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_SET_OPTIONS_H_

#include <string>
#include <vector>

#include "firebase/firestore/field_path.h"

namespace firebase {
namespace firestore {

/**
 * An options object that configures the behavior of Set() calls. By providing
 * the SetOptions objects returned by Merge(), the Set() methods in
 * DocumentReference, WriteBatch and Transaction can be configured to perform
 * granular merges instead of overwriting the target documents in their
 * entirety.
 */
class SetOptions {
 public:
  enum class Type {
    kOverwrite,
    kMergeAll,
    kMergeSpecific,
  };

  /**
   * Default constructor. This creates an invalid SetOptions. Attempting
   * to perform any operations on this instance will fail (and cause a crash)
   * unless a valid SetOptions has been assigned to it.
   */
  SetOptions() = default;

  /** Copy constructor. */
  SetOptions(const SetOptions& value) = default;

  /** Move constructor. */
  SetOptions(SetOptions&& value) = default;

  virtual ~SetOptions();

  /** Copy assignment operator. */
  SetOptions& operator=(const SetOptions& value) = default;

  /** Move assignment operator. */
  SetOptions& operator=(SetOptions&& value) = default;

  /**
   * Returns an instance that can be used to change the behavior of set() calls
   * to only replace the values specified in its data argument. Fields omitted
   * from the set() call will remain untouched.
   */
  static SetOptions Merge();

  /**
   * Returns an instance that can be used to change the behavior of set() calls
   * to only replace the fields under fieldPaths. Any field that is not
   * specified in fieldPaths is ignored and remains untouched.
   *
   * It is an error to pass a SetOptions object to a set() call that is missing
   * a value for any of the fields specified here.
   *
   * @param fields The list of fields to merge. Fields can contain dots to
   * reference nested fields within the document.
   */
  static SetOptions MergeField(const std::vector<std::string>& fields);

  /**
   * Returns an instance that can be used to change the behavior of set() calls
   * to only replace the fields under fieldPaths. Any field that is not
   * specified in fieldPaths is ignored and remains untouched.
   *
   * It is an error to pass a SetOptions object to a set() call that is missing
   * a value for any of the fields specified here in its to data argument.
   *
   * @param fields The list of fields to merge.
   */
  static SetOptions MergeField(const std::vector<FieldPath>& fields);

 private:
  friend class SetOptionsInternal;

  SetOptions(Type type, std::vector<FieldPath> fields);

  Type type_ = Type::kOverwrite;
  std::vector<FieldPath> fields_;
};

}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_SET_OPTIONS_H_
