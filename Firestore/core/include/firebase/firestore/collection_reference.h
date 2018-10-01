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

#ifndef FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_COLLECTION_REFERENCE_H_
#define FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_COLLECTION_REFERENCE_H_

#include <string>

#include "firebase/firestore/document_reference.h"
#include "firebase/firestore/field_value.h"
#include "firebase/firestore/map_field_value.h"
#include "firebase/firestore/query.h"
#include "firebase/future.h"

namespace firebase {
namespace firestore {

class CollectionReferenceInternal;
class DocumentReference;
class FieldValue;
class FirestoreInternal;

/**
 * A CollectionReference refers to a collection of documents location in a
 * Firestore database and can be used for adding documents, getting document
 * references, and querying for documents.
 */
class CollectionReference : public Query {
 public:
  /**
   * @brief Default constructor. This creates an invalid CollectionReference.
   * Attempting to perform any operations on this reference will fail unless a
   * valid CollectionReference has been assigned to it.
   */
  CollectionReference();

  /**
   * @brief Copy constructor. It's totally okay (and efficient) to copy
   * CollectionReference instances, as they simply point to the same location in
   * the database.
   *
   * @param[in] reference CollectionReference to copy from.
   */
  CollectionReference(const CollectionReference& reference);

  /**
   * @brief Move constructor. Moving is an efficient operation for
   * CollectionReference instances.
   *
   * @param[in] reference CollectionReference to move data from.
   */
  CollectionReference(CollectionReference&& reference);

  /**
   * @brief Copy assignment operator. It's totally okay (and efficient) to copy
   * CollectionReference instances, as they simply point to the same location in
   * the database.
   *
   * @param[in] reference CollectionReference to copy from.
   *
   * @returns Reference to the destination CollectionReference.
   */
  CollectionReference& operator=(const CollectionReference& reference);

  /**
   * @brief Move assignment operator. Moving is an efficient operation for
   * CollectionReference instances.
   *
   * @param[in] reference CollectionReference to move data from.
   *
   * @returns Reference to the destination CollectionReference.
   */
  CollectionReference& operator=(CollectionReference&& reference);

  /**
   * @brief Gets the id of the referenced collection.
   *
   * @return The id as a C string, which will remain valid in memory until the
   * CollectionReference itself goes away.
   */
  virtual const char* collection_id() const;

  /**
   * @brief Gets the id of the referenced collection.
   *
   * @return The id as a std::string.
   */
  virtual std::string collection_id_string() const;

  /**
   * @brief Returns the path of this collection (relative to the root of the
   * database) as a slash-separated string.
   *
   * @returns The path as a C string, which will remain valid in memory until
   * the DocumentReference itself goes away.
   */
  virtual const char* path() const;

  /**
   * @brief Returns the path of this collection (relative to the root of the
   * database) as a slash-separated string.
   *
   * @returns The path as a std::string.
   */
  virtual std::string path_string() const;

  // TODO(zxu123): add the parent() once we made the design decision.

  /**
   * @brief Returns a DocumentReference pointing to a new document with an auto-
   * generated id within this collection.
   *
   * @return A DocumentReference pointing to the new document.
   */
  virtual DocumentReference Document() const;

  /**
   * @brief Gets a DocumentReference instance that refers to the document at the
   * specified path within this collection.
   *
   * @param[in] document_path A slash-separated relative path to a document.
   * The pointer only needs to be valid during this call.
   *
   * @return The DocumentReference instance.
   */
  virtual DocumentReference Document(const char* document_path) const;

  /**
   * @brief Gets a DocumentReference instance that refers to the document at the
   * specified path within this collection.
   *
   * @param[in] document_path A slash-separated relative path to a document.
   *
   * @return The DocumentReference instance.
   */
  virtual DocumentReference Document(const std::string& document_path) const;

  /**
   * @brief Adds a new document to this collection with the specified data,
   * assigning it a document id automatically.
   *
   * @param data A map containing the data for the new document.
   *
   * @return A Future that will be resolved with the DocumentReference of the
   * newly created document.
   */
  virtual Future<DocumentReference> Add(const MapFieldValue& data);

  /**
   * @brief Gets the result of the most recent call to Add().
   *
   * @return The result of last call to Add() or an invalid Future, if there is
   * no such call.
   */
  // TODO(zxu123): raise this in Firebase API discussion for the naming concern.
  virtual Future<DocumentReference> AddLastResult() const;

 protected:
  explicit CollectionReference(CollectionReferenceInternal* internal);

 private:
  friend class DocumentReference;
  friend class DocumentReferenceInternal;
  friend class FirestoreInternal;

  CollectionReferenceInternal* internal() const;
};

}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_COLLECTION_REFERENCE_H_
