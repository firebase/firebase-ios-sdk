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

#ifndef FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_TRANSACTION_H_
#define FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_TRANSACTION_H_

#include "firebase/firestore/document_reference.h"
#include "firebase/firestore/document_snapshot.h"
#include "firebase/firestore/map_field_value.h"

namespace firebase {
namespace firestore {

class TransactionInternal;

/**
 * Transaction provides methods to read and write data within a transaction.
 */
class Transaction {
 public:
  /**
   * Default constructor. This creates an invalid Transaction. Attempting
   * to perform any operations on this instance will fail (and cause a crash)
   * unless a valid Transaction has been assigned to it.
   */
  Transaction();

  /**
   * Copy constructor. It's totally okay (and efficient) to copy
   * Transaction instances.
   *
   * @param[in] value Transaction to copy from.
   */
  Transaction(const Transaction& value);

  /**
   * Move constructor. Moving is an efficient operation for Transaction
   * instances.
   *
   * @param[in] value Transaction to move data from.
   */
  Transaction(Transaction&& value);

  virtual ~Transaction();

  /**
   * Copy assignment operator. It's totally okay (and efficient) to copy
   * Transaction instances.
   *
   * @param[in] value Transaction to copy from.
   *
   * @returns Reference to the destination Transaction.
   */
  Transaction& operator=(const Transaction& value);

  /**
   * Move assignment operator. Moving is an efficient operation for
   * Transaction instances.
   *
   * @param[in] value Transaction to move data from.
   *
   * @returns Reference to the destination Transaction.
   */
  Transaction& operator=(Transaction&& value);

  /**
   * Overwrites the document referred to by the provided reference. If the
   * document does not yet exist, it will be created. If a document already
   * exists, it will be overwritten.
   *
   * @param document The DocumentReference to overwrite.
   * @param data A map of the fields and values for the document.
   * @return This Transaction instance. Used for chaining method calls.
   */
  virtual Transaction& Set(const DocumentReference& document,
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
   * @return This Transaction instance. Used for chaining method calls.
   */
  virtual Transaction& Set(const DocumentReference& document,
                           const MapFieldValue& data,
                           const SetOptions& options);

  /**
   * Updates fields in the document referred to by the provided reference. If no
   * document exists yet, the update will fail.
   *
   * @param document The DocumentReference to update.
   * @param data A map of field / value pairs to update. Fields can contain dots
   * to reference nested fields within the document.
   * @return This Transaction instance. Used for chaining method calls.
   */
  virtual Transaction& Update(const DocumentReference& document,
                              const MapFieldValue& data);

  /**
   * Deletes the document referred to by the provided reference.
   *
   * @param document The DocumentReference to delete.
   * @return This Transaction instance. Used for chaining method calls.
   */
  virtual Transaction& Delete(const DocumentReference& document);

  /**
   * Reads the document referred by the provided reference.
   *
   * @param document The DocumentReference to read.
   * @return The contents of the Document at this DocumentReference.
   */
  virtual DocumentSnapshot Get(const DocumentReference& document);

 protected:
  explicit Transaction(TransactionInternal* internal);

 private:
  friend class FirestoreInternal;

  TransactionInternal* internal_ = nullptr;
};

}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_TRANSACTION_H_
