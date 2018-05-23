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

namespace firebase {
namespace firestore {

class CollectionReferenceInternal;
class FirestoreInternal;

/**
 * A CollectionReference refers to a collection of documents location in a
 * Firestore database and can be used for adding documents, getting document
 * references, and querying for documents.
 */
// TODO(zxu123): add more methods to complete the class and make it useful.
class CollectionReference {
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

  /** @brief Required virtual destructor. */
  virtual ~CollectionReference();

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

 protected:
  explicit CollectionReference(CollectionReferenceInternal* internal);

 private:
  friend class DocumentReference;
  friend class DocumentReferenceInternal;
  friend class FirestoreInternal;

  // TODO(zxu123): investigate possibility to use std::unique_ptr or
  // firebase::UniquePtr.
  CollectionReferenceInternal* internal_ = nullptr;
};

}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_COLLECTION_REFERENCE_H_
