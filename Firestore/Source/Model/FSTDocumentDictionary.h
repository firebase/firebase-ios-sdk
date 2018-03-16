/*
 * Copyright 2017 Google
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

#import <Foundation/Foundation.h>

#include <map>

#import "Firestore/third_party/Immutable/FSTImmutableSortedDictionary.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"

@class FSTDocument;
@class FSTMaybeDocument;

NS_ASSUME_NONNULL_BEGIN

/** Convenience type for a map of keys to MaybeDocuments, since they are so common. */
typedef std::map<firebase::firestore::model::DocumentKey, FSTMaybeDocument *>
    MaybeDocumentDictionary;

/** Convenience type for a map of keys to Documents, since they are so common. */
typedef std::map<firebase::firestore::model::DocumentKey, FSTDocument *> DocumentDictionary;

class DocumentDictionaryBuilder {
  /** Returns a new set of MaybeDocument using the DocumentKeyComparator. */
  static MaybeDocumentDictionary CreateMaybeDocumentDictionary();

  /** Returns a set of Document using the DocumentKeyComparator. */
  static DocumentDictionary *CreateDocumentDictionary();
};

@end

    NS_ASSUME_NONNULL_END
