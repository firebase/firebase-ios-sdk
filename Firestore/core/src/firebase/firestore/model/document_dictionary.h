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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_DOCUMENT_DICTIONARY_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_DOCUMENT_DICTIONARY_H_

#include <map>

#include "Firestore/core/src/firebase/firestore/model/document_key.h"

@class FSTDocument;
@class FSTMaybeDocument;

namespace firebase {
namespace firestore {
namespace model {

/** Convenience type for a map of keys to MaybeDocuments, since they are so
 * common. */
typedef std::map<firebase::firestore::model::DocumentKey, FSTMaybeDocument*>
    MaybeDocumentDictionary;

/** Convenience type for a map of keys to Documents, since they are so common.
 */
typedef std::map<firebase::firestore::model::DocumentKey, FSTDocument*>
    DocumentDictionary;

inline MaybeDocumentDictionary ToMaybeDocumentDictionary(
    const DocumentDictionary& docs) {
  MaybeDocumentDictionary result{};
  for (const auto& iter : docs) {
    result[iter.first] = (FSTMaybeDocument*)iter.second;
  }
  return result;
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_DOCUMENT_DICTIONARY_H_
