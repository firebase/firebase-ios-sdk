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

#ifndef FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_DOCUMENT_REFERENCE_H_
#define FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_DOCUMENT_REFERENCE_H_

#include <string>

#if defined(FIREBASE_USE_STD_FUNCTION)
#include <functional>
#endif

#include "firebase/app.h"
#include "firebase/firestore/collection_reference.h"
#include "firebase/firestore/document_snapshot.h"
#include "firebase/firestore/event_listener.h"
#include "firebase/firestore/field_value.h"
#include "firebase/firestore/firestore.h"
#include "firebase/firestore/firestore_errors.h"
#include "firebase/firestore/listener_registration.h"
#include "firebase/firestore/map_field_value.h"
#include "firebase/firestore/metadata_changes.h"
#include "firebase/firestore/set_options.h"
#include "firebase/firestore/source.h"
#include "firebase/future.h"

// TODO(rsgowman): Note that RTDB uses:
//   #if defined(FIREBASE_USE_MOVE_OPERATORS) || defined(DOXYGEN)
// to protect move operators from older compilers. But all our supported
// compilers support this, so we've skipped the #if guard. This TODO comment is
// here so we don't forget to mention this during the API review, and should be
// removed once this note has migrated to the API review doc.

namespace firebase {
namespace firestore {

class CollectionReference;
class DocumentReferenceInternal;
class DocumentSnapshot;
class FieldValue;
class Firestore;
class FirestoreInternal;

/**
 * A DocumentReference refers to a document location in a Firestore database and
 * can be used to write, read, or listen to the location. There may or may not
 * exist a document at the referenced location. A DocumentReference can also be
 * used to create a CollectionReference to a subcollection.
 *
 * Create a DocumentReference via Firebase::Document(const string& path).
 *
 * NOT thread-safe: an instance should not be used from multiple threads
 *
 * Subclassing Note: Firestore classes are not meant to be subclassed except for
 * use in test mocks. Subclassing is not supported in production code and new
 * SDK releases may break code that does so.
 */
class DocumentReference {
 public:
  /**
   * @brief Default constructor. This creates an invalid DocumentReference.
   * Attempting to perform any operations on this reference will fail (and cause
   * a crash) unless a valid DocumentReference has been assigned to it.
   */
  DocumentReference();

  /**
   * @brief Copy constructor. It's totally okay (and efficient) to copy
   * DocumentReference instances, as they simply point to the same location in
   * the database.
   *
   * @param[in] reference DocumentReference to copy from.
   */
  DocumentReference(const DocumentReference& reference);

  /**
   * @brief Move constructor. Moving is an efficient operation for
   * DocumentReference instances.
   *
   * @param[in] reference DocumentReference to move data from.
   */
  DocumentReference(DocumentReference&& reference);

  virtual ~DocumentReference();

  /**
   * @brief Copy assignment operator. It's totally okay (and efficient) to copy
   * DocumentReference instances, as they simply point to the same location in
   * the database.
   *
   * @param[in] reference DocumentReference to copy from.
   *
   * @returns Reference to the destination DocumentReference.
   */
  DocumentReference& operator=(const DocumentReference& reference);

  /**
   * @brief Move assignment operator. Moving is an efficient operation for
   * DocumentReference instances.
   *
   * @param[in] reference DocumentReference to move data from.
   *
   * @returns Reference to the destination DocumentReference.
   */
  DocumentReference& operator=(DocumentReference&& reference);

  /**
   * @brief Returns the Firestore instance associated with this document
   * reference.
   *
   * The pointer will remain valid indefinitely.
   *
   * @returns Firebase Firestore instance that this DocumentReference refers to.
   */
  virtual const Firestore* firestore() const;

  /**
   * @brief Returns the Firestore instance associated with this document
   * reference.
   *
   * The pointer will remain valid indefinitely.
   *
   * @returns Firebase Firestore instance that this DocumentReference refers to.
   */
  virtual Firestore* firestore();

  /**
   * @brief Returns the string id of this document location.
   *
   * The pointer is only valid while the DocumentReference remains in memory.
   *
   * @returns String id of this document location, which will remain valid in
   * memory until the DocumentReference itself goes away.
   */
  virtual const char* document_id() const;

  /**
   * @brief Returns the string id of this document location.
   *
   * @returns String id of this document location.
   */
  virtual std::string document_id_string() const;

  /**
   * @brief Returns the path of this document (relative to the root of the
   * database) as a slash-separated string.
   *
   * The pointer is only valid while the DocumentReference remains in memory.
   *
   * @returns String path of this document location, which will remain valid in
   * memory until the DocumentReference itself goes away.
   */
  virtual const char* path() const;

  /**
   * @brief Returns the path of this document (relative to the root of the
   * database) as a slash-separated string.
   *
   * @returns String path of this document location.
   */
  virtual std::string path_string() const;

  /**
   * @brief Returns a CollectionReference to the collection that contains this
   * document.
   */
  virtual CollectionReference parent() const;

  /**
   * @brief Returns a CollectionReference instance that refers to the
   * subcollection at the specified path relative to this document.
   *
   * @param[in] collection_path A slash-separated relative path to a
   * subcollection. The pointer only needs to be valid during this call.
   *
   * @return The CollectionReference instance.
   */
  virtual CollectionReference Collection(const char* collection_path) const;

  /**
   * @brief Returns a CollectionReference instance that refers to the
   * subcollection at the specified path relative to this document.
   *
   * @param[in] collection_path A slash-separated relative path to a
   * subcollection.
   *
   * @return The CollectionReference instance.
   */
  virtual CollectionReference Collection(
      const std::string& collection_path) const;

  /**
   * @brief Reads the document referenced by this DocumentReference.
   *
   * @return A Future that will be resolved with the contents of the Document at
   * this DocumentReference.
   */
  virtual Future<DocumentSnapshot> Get() const;

  /**
   * @brief Reads the document referenced by this DocumentReference.
   *
   * By default, Get() attempts to provide up-to-date data when possible by
   * waiting for data from the server, but it may return cached data or fail if
   * you are offline and the server cannot be reached. This behavior can be
   * altered via the {@link Source} parameter.
   *
   * @param[in] source A value to configure the get behavior.
   *
   * @return A Future that will be resolved with the contents of the Document at
   * this DocumentReference.
   */
  virtual Future<DocumentSnapshot> Get(Source source) const;

  /**
   * @brief Gets the result of the most recent call to either of the Get()
   * methods.
   *
   * @return The result of last call to Get() or an invalid Future, if there is
   * no such call.
   */
  // TODO(zxu123): raise this in Firebase API discussion for the naming concern.
  virtual Future<DocumentSnapshot> GetLastResult() const;

  /**
   * @brief Writes to the document referred to by this DocumentReference.
   *
   * If the document does not yet exist, it will be created. If you pass
   * SetOptions, the provided data can be merged into an existing document.
   *
   * @param[in] data A map of the fields and values for the document.
   *
   * @return A Future that will be resolved when the write finishes.
   */
  virtual Future<void> Set(const MapFieldValue& data);

  /**
   * @brief Writes to the document referred to by this DocumentReference.
   *
   * If the document does not yet exist, it will be created. If you pass
   * SetOptions, the provided data can be merged into an existing document.
   *
   * @param[in] data A map of the fields and values for the document.
   * @param[in] options An object to configure the set behavior.
   *
   * @return A Future that will be resolved when the write finishes.
   */
  virtual Future<void> Set(const MapFieldValue& data,
                           const SetOptions& options);

  /**
   * @brief Gets the result of the most recent call to either of the Set()
   * methods.
   *
   * @return The result of last call to Set() or an invalid Future, if there is
   * no such call.
   */
  // TODO(zxu123): raise this in Firebase API discussion for the naming concern.
  virtual Future<void> SetLastResult() const;

  /**
   * @brief Updates fields in the document referred to by this
   * DocumentReference.
   *
   * If no document exists yet, the update will fail.
   *
   * @param[in] data A map of field / value pairs to update. Fields can contain
   * dots to reference nested fields within the document.
   *
   * @return A Future that will be resolved when the write finishes.
   */
  virtual Future<void> Update(const MapFieldValue& data);

  /**
   * @brief Gets the result of the most recent call to Update().
   *
   * @return The result of last call to Update() or an invalid Future, if there
   * is no such call.
   */
  // TODO(zxu123): raise this in Firebase API discussion for the naming concern.
  virtual Future<void> UpdateLastResult() const;

  /**
   * @brief Removes the document referred to by this DocumentReference.
   *
   * @return A Future that will be resolved when the delete completes.
   */
  virtual Future<void> Delete();

  /**
   * @brief Gets the result of the most recent call to Delete().
   *
   * @return The result of last call to Delete() or an invalid Future, if there
   * is no such call.
   */
  // TODO(zxu123): raise this in Firebase API discussion for the naming concern.
  virtual Future<void> DeleteLastResult() const;

  /**
   * @brief Starts listening to the document referenced by this
   * DocumentReference.
   *
   * @param[in] listener The event listener that will be called with the
   * snapshots, which must remain in memory until you remove the listener from
   * this DocumentReference. (Ownership is not transferred; you are responsible
   * for making sure that listener is valid as long as this DocumentReference is
   * valid and the listener is registered.)
   *
   * @return A registration object that can be used to remove the listener.
   */
  virtual ListenerRegistration AddSnapshotListener(
      EventListener<DocumentSnapshot>* listener);

  /**
   * @brief Starts listening to the document referenced by this
   * DocumentReference.
   *
   * @param[in] listener The event listener that will be called with the
   * snapshots, which must remain in memory until you remove the listener from
   * this DocumentReference. (Ownership is not transferred; you are responsible
   * for making sure that listener is valid as long as this DocumentReference is
   * valid and the listener is registered.)
   * @param[in] metadata_changes Indicates whether metadata-only changes (i.e.
   * only DocumentSnapshot.getMetadata() changed) should trigger snapshot
   * events.
   *
   * @return A registration object that can be used to remove the listener.
   */
  virtual ListenerRegistration AddSnapshotListener(
      EventListener<DocumentSnapshot>* listener,
      MetadataChanges metadata_changes);

#if defined(FIREBASE_USE_STD_FUNCTION) || defined(DOXYGEN)
  /**
   * @brief Starts listening to the document referenced by this
   * DocumentReference.
   *
   * @param[in] callback function or lambda to call. When this function is
   * called, snapshot value is valid if and only if error is Error::Ok.
   *
   * @return A registration object that can be used to remove the listener.
   *
   * @note This method is not available when using STLPort on Android, as
   * std::function is not supported on STLPort.
   */
  virtual ListenerRegistration AddSnapshotListener(
      std::function<void(const DocumentSnapshot&, Error)> callback);

  /**
   * @brief Starts listening to the document referenced by this
   * DocumentReference.
   *
   * @param[in] callback function or lambda to call. When this function is
   * called, snapshot value is valid if and only if error is Error::Ok.
   * @param[in] metadata_changes Indicates whether metadata-only changes (i.e.
   * only DocumentSnapshot.getMetadata() changed) should trigger snapshot
   * events.
   *
   * @return A registration object that can be used to remove the listener.
   *
   * @note This method is not available when using STLPort on Android, as
   * std::function is not supported on STLPort.
   */
  virtual ListenerRegistration AddSnapshotListener(
      std::function<void(const DocumentSnapshot&, Error)> callback,
      MetadataChanges metadata_changes);
#endif  // defined(FIREBASE_USE_STD_FUNCTION) || defined(DOXYGEN)

 protected:
  explicit DocumentReference(DocumentReferenceInternal* internal);

 private:
  friend class CollectionReferenceInternal;
  friend class DocumentSnapshotInternal;
  friend class FieldValueInternal;
  friend class FirestoreInternal;
  friend class TransactionInternal;
  friend class WriteBatchInternal;

  // TODO(zxu123): investigate possibility to use std::unique_ptr or
  // firebase::UniquePtr.
  DocumentReferenceInternal* internal_ = nullptr;
};

bool operator==(const DocumentReference& lhs, const DocumentReference& rhs);

inline bool operator!=(const DocumentReference& lhs,
                       const DocumentReference& rhs) {
  return !(lhs == rhs);
}

// TODO(rsgowman): probably define and inline here.
bool operator<(const DocumentReference& lhs, const DocumentReference& rhs);

inline bool operator>(const DocumentReference& lhs,
                      const DocumentReference& rhs) {
  return rhs < lhs;
}

inline bool operator<=(const DocumentReference& lhs,
                       const DocumentReference& rhs) {
  return !(lhs > rhs);
}

inline bool operator>=(const DocumentReference& lhs,
                       const DocumentReference& rhs) {
  return !(lhs < rhs);
}

}  // namespace firestore
}  // namespace firebase

namespace std {
// TODO(rsgowman): NB that specialization of std::hash deviates from the Google
// C++ style guide. But we think this is probably ok in this case since:
// a) It's the standard way of doing this outside of Google (as the style guide
// itself points out), and
// b) This has a straightforward hash function anyway (just hash the path) so I
// don't think the concerns in the style guide are going to bite us.
//
// Raise this concern during the API review.
template <>
struct hash<firebase::firestore::DocumentReference> {
  std::size_t operator()(
      const firebase::firestore::DocumentReference& doc_ref) const;
};
}  // namespace std

#endif  // FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_DOCUMENT_REFERENCE_H_
