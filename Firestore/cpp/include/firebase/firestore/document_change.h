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

#ifndef FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_DOCUMENT_CHANGE_H_
#define FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_DOCUMENT_CHANGE_H_

#include <cstddef>

#include "firebase/firestore/document_snapshot.h"

namespace firebase {
namespace firestore {

class DocumentChangeInternal;

/**
 * A DocumentChange represents a change to the documents matching a query. It
 * contains the document affected and the type of change that occurred (added,
 * modified, or removed).
 */
class DocumentChange {
 public:
  enum class Type {
    kAdded,
    kModified,
    kRemoved,
  };

  static const constexpr std::size_t npos = static_cast<std::size_t>(-1);

  /**
   * @brief Default constructor. This creates an invalid DocumentChange.
   * Attempting to perform any operations on this instance will fail (and cause
   * a crash) unless a valid DocumentChange has been assigned to it.
   */
  DocumentChange();

  /** @brief Copy constructor. */
  DocumentChange(const DocumentChange& value);

  /** @brief Move constructor. */
  DocumentChange(DocumentChange&& value);

  virtual ~DocumentChange();

  /** @brief Copy assignment operator. */
  DocumentChange& operator=(const DocumentChange& value);

  /** @brief Move assignment operator. */
  DocumentChange& operator=(DocumentChange&& value);

  /**
   * Returns the type of change that occurred (added, modified, or removed).
   */
  virtual Type type() const;

  /**
   * @brief The document affected by this change.
   *
   * Returns the newly added or modified document if this DocumentChange is for
   * an updated document. Returns the deleted document if this document change
   * represents a removal.
   */
  virtual DocumentSnapshot document() const;

  /**
   * The index of the changed document in the result set immediately prior to
   * this DocumentChange (i.e. supposing that all prior DocumentChange objects
   * have been applied). Returns npos for 'added' events.
   */
  virtual std::size_t old_index() const;

  /**
   * The index of the changed document in the result set immediately after this
   * DocumentChange (i.e. supposing that all prior DocumentChange objects and
   * the current DocumentChange object have been applied). Returns npos for
   * 'removed' events.
   */
  virtual std::size_t new_index() const;

 protected:
  explicit DocumentChange(DocumentChangeInternal* internal);

 private:
  friend class FirestoreInternal;

  DocumentChangeInternal* internal_ = nullptr;
};

}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_DOCUMENT_CHANGE_H_
