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

#ifndef FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_DOCUMENT_SNAPSHOT_H_
#define FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_DOCUMENT_SNAPSHOT_H_

#include <map>
#include <string>

#include "firebase/firestore/document_reference.h"
#include "firebase/firestore/field_value.h"
#include "firebase/firestore/firestore.h"
#include "firebase/firestore/snapshot_metadata.h"

namespace firebase {
namespace firestore {

class DocumentReference;
class DocumentSnapshotInternal;
class Firestore;
class FirestoreInternal;

/**
 * A DocumentSnapshot contains data read from a document in your Firestore
 * database. The data can be extracted with the GetData() method or by using
 * Get() to access a specific field.
 *
 * For a DocumentSnapshot that points to a non-existing document, any data
 * access will cause a failed assertion. You can use the exists() method to
 * explicitly verify a documents existence.
 */
class DocumentSnapshot {
 public:
  enum class ServerTimestampBehavior {
    kDefault,
    kNone,
    kEstimate,
    kPrevious,
  };

  /**
   * @brief Default constructor. This creates an invalid DocumentSnapshot.
   * Attempting to perform any operations on this instance will fail (and cause
   * a crash) unless a valid DocumentSnapshot has been assigned to it.
   */
  DocumentSnapshot();

  /**
   * @brief Copy constructor. It's totally okay (and efficient) to copy
   * DocumentSnapshot instances.
   *
   * @param[in] snapshot DocumentSnapshot to copy from.
   */
  DocumentSnapshot(const DocumentSnapshot& snapshot);

  /**
   * @brief Move constructor. Moving is an efficient operation for
   * DocumentSnapshot instances.
   *
   * @param[in] snapshot DocumentSnapshot to move data from.
   */
  DocumentSnapshot(DocumentSnapshot&& snapshot);

  virtual ~DocumentSnapshot();

  /**
   * @brief Copy assignment operator. It's totally okay (and efficient) to copy
   * DocumentSnapshot instances.
   *
   * @param[in] snapshot DocumentSnapshot to copy from.
   *
   * @returns Reference to the destination DocumentSnapshot.
   */
  DocumentSnapshot& operator=(const DocumentSnapshot& snapshot);

  /**
   * @brief Move assignment operator. Moving is an efficient operation for
   * DocumentSnapshot instances.
   *
   * @param[in] snapshot DocumentSnapshot to move data from.
   *
   * @returns Reference to the destination DocumentSnapshot.
   */
  DocumentSnapshot& operator=(DocumentSnapshot&& snapshot);

  /**
   * @brief Returns the Firestore instance associated with this document
   * snapshot.
   *
   * The pointer will remain valid indefinitely.
   *
   * @returns Firebase Firestore instance that this DocumentSnapshot refers to.
   */
  virtual const Firestore* firestore() const;

  /**
   * @brief Returns the Firestore instance associated with this document
   * snapshot.
   *
   * The pointer will remain valid indefinitely.
   *
   * @returns Firebase Firestore instance that this DocumentSnapshot refers to.
   */
  virtual Firestore* firestore();

  /**
   * @brief Returns the string id of the document for which this
   * DocumentSnapshot contains data.
   *
   * The pointer is only valid while the DocumentSnapshot remains in memory.
   *
   * @returns String id of this document location, which will remain valid in
   * memory until the DocumentSnapshot itself goes away.
   */
  virtual const char* document_id() const;

  /**
   * @brief Returns the string id of the document for which this
   * DocumentSnapshot contains data.
   *
   * @returns String id of this document location.
   */
  virtual std::string id_string() const;

  /**
   * @brief Returns the document location for which this DocumentSnapshot
   * contains data.
   *
   * @returns DocumentReference of this document location.
   */
  virtual DocumentReference reference() const;

  /**
   * @brief Returns the metadata about this snapshot concerning its source and
   * if it has local modifications.
   *
   * @returns SnapshotMetadata about this snapshot.
   */
  virtual SnapshotMetadata metadata() const;

  /**
   * @brief Explicitly verify a documents existence.
   *
   * @returns True if the document exists in this snapshot.
   */
  virtual bool exists() const;

  /**
   * Retrieves all fields in the document as a map.
   *
   * @return A map containing all fields in the document.
   */
  virtual std::map<std::string, FieldValue> GetData() const;

  /**
   * Retrieves all fields in the document as a map.
   *
   * @param serverTimestampBehavior Configures how server timestamps that have
   * not yet been set to their final value are returned from the snapshot.
   *
   * @return A map containing all fields in the document.
   */
  virtual std::map<std::string, FieldValue> GetData(
      ServerTimestampBehavior stb) const;

  /**
   * @brief Retrieves a specific field from the document.
   *
   * @param field String id of the field to retrieve. The pointer only needs to
   * be valid during this call.
   *
   * @return The value contained in the field.
   */
  virtual FieldValue Get(const char* field) const;

  /**
   * @brief Retrieves a specific field from the document.
   *
   * @param field String id of the field to retrieve. The pointer only needs to
   * be valid during this call.
   * @param serverTimestampBehavior Configures how server timestamps that have
   * not yet been set to their final value are returned from the snapshot.
   *
   * @return The value contained in the field.
   */
  virtual FieldValue Get(const char* field, ServerTimestampBehavior stb) const;

  /**
   * @brief Retrieves a specific field from the document.
   *
   * @param field String id of the field to retrieve.
   *
   * @return The value contained in the field.
   */
  virtual FieldValue Get(const std::string& field) const;

  /**
   * @brief Retrieves a specific field from the document.
   *
   * @param field String id of the field to retrieve.
   * @param serverTimestampBehavior Configures how server timestamps that have
   * not yet been set to their final value are returned from the snapshot.
   *
   * @return The value contained in the field.
   */
  virtual FieldValue Get(const std::string& field,
                         ServerTimestampBehavior stb) const;

 protected:
  explicit DocumentSnapshot(DocumentSnapshotInternal* internal);

 private:
  friend class FirestoreInternal;
  friend class QueryInternal;

  DocumentSnapshotInternal* internal_ = nullptr;
};

}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_DOCUMENT_SNAPSHOT_H_
