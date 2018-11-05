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

#ifndef FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_WRITE_BATCH_H_
#define FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_WRITE_BATCH_H_

#include "firebase/firestore/document_reference.h"
#include "firebase/firestore/map_field_value.h"

namespace firebase {
namespace firestore {

class WriteBatchInternal;

/**
 * A write batch is used to perform multiple writes as a single atomic unit.
 *
 * A WriteBatch object provides methods for adding writes to the write batch.
 * None of the writes will be committed (or visible locally) until commit() is
 * called.
 *
 * Unlike transactions, write batches are persisted offline and therefore are
 * preferable when you don't need to condition your writes on read data.
 */
class WriteBatch {
 public:
  /**
   * Default constructor. This creates an invalid WriteBatch. Attempting
   * to perform any operations on this instance will fail (and cause a crash)
   * unless a valid WriteBatch has been assigned to it.
   */
  WriteBatch();

  /**
   * Copy constructor. It's totally okay (and efficient) to copy
   * WriteBatch instances.
   *
   * @param[in] value WriteBatch to copy from.
   */
  WriteBatch(const WriteBatch& value);

  /**
   * Move constructor. Moving is an efficient operation for WriteBatch
   * instances.
   *
   * @param[in] value WriteBatch to move data from.
   */
  WriteBatch(WriteBatch&& value);

  virtual ~WriteBatch();

  /**
   * Copy assignment operator. It's totally okay (and efficient) to copy
   * WriteBatch instances.
   *
   * @param[in] value WriteBatch to copy from.
   *
   * @returns Reference to the destination WriteBatch.
   */
  WriteBatch& operator=(const WriteBatch& value);

  /**
   * Move assignment operator. Moving is an efficient operation for
   * WriteBatch instances.
   *
   * @param[in] value WriteBatch to move data from.
   *
   * @returns Reference to the destination WriteBatch.
   */
  WriteBatch& operator=(WriteBatch&& value);

  /**
   * Overwrites the document referred to by the provided reference. If the
   * document does not yet exist, it will be created. If a document already
   * exists, it will be overwritten.
   *
   * @param document The DocumentReference to overwrite.
   * @param data A map of the fields and values for the document.
   * @return This WriteBatch instance. Used for chaining method calls.
   */
  virtual WriteBatch& Set(const DocumentReference& document,
                          const MapFieldValue& data);

  /**
   * Overwrites the document referred to by the provided reference. If the
   * document does not yet exist, it will be created. If a document already
   * exists, it will be overwritten. If you pass {@link SetOptions}, the
   * provided data can be merged into an existing document.
   *
   * @param document The DocumentReference to overwrite.
   * @param data A map of the fields and values for the document.
   * @param options An object to configure the set behavior.
   * @return This WriteBatch instance. Used for chaining method calls.
   */
  virtual WriteBatch& Set(const DocumentReference& document,
                          const MapFieldValue& data,
                          const SetOptions& options);

  /**
   * Updates fields in the document referred to by the provided reference. If no
   * document exists yet, the update will fail.
   *
   * @param document The DocumentReference to update.
   * @param data A map of field / value pairs to update. Fields can contain dots
   * to reference nested fields within the document.
   * @return This WriteBatch instance. Used for chaining method calls.
   */
  virtual WriteBatch& Update(const DocumentReference& document,
                             const MapFieldValue& data);

  /**
   * Deletes the document referred to by the provided reference.
   *
   * @param document The DocumentReference to delete.
   * @return This WriteBatch instance. Used for chaining method calls.
   */
  virtual WriteBatch& Delete(const DocumentReference& document);

  /**
   * Commits all of the writes in this write batch as a single atomic unit.
   *
   * @return A Future that will be resolved when the write finishes.
   */
  virtual Future<void> Commit();

  /**
   * Gets the result of the most recent call to Commit() methods.
   *
   * @return The result of last call to Commit() or an invalid Future, if there
   * is no such call.
   */
  // TODO(zxu123): raise this in Firebase API discussion for the naming concern.
  virtual Future<void> CommitLastResult() const;

 protected:
  explicit WriteBatch(WriteBatchInternal* internal);

 private:
  friend class FirestoreInternal;
  friend class WriteBatchInternal;

  WriteBatchInternal* internal_ = nullptr;
};

}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_WRITE_BATCH_H_
