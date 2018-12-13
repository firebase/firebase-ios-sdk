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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_REMOTE_DOCUMENT_CACHE_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_REMOTE_DOCUMENT_CACHE_H_

#if !defined(__OBJC__)
#error "For now, this file must only be included by ObjC source files."
#endif  // !defined(__OBJC__)

#import <Foundation/Foundation.h>

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/document_map.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"

@class FSTMaybeDocument;
@class FSTQuery;

NS_ASSUME_NONNULL_BEGIN

namespace firebase {
namespace firestore {
namespace local {

class RemoteDocumentCache {
 public:
  virtual ~RemoteDocumentCache() {
  }

  virtual void AddEntry(FSTMaybeDocument *document) = 0;
  virtual void RemoveEntry(const model::DocumentKey &key) = 0;

  virtual FSTMaybeDocument *_Nullable Get(const model::DocumentKey &key) = 0;
  virtual model::MaybeDocumentMap GetAll(const model::DocumentKeySet &keys) = 0;
  virtual model::DocumentMap GetMatchingDocuments(FSTQuery *query) = 0;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

NS_ASSUME_NONNULL_END

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_REMOTE_DOCUMENT_CACHE_H_
