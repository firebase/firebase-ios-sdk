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

#import "Firestore/Example/Tests/API/FSTAPIHelpers.h"

#import <FirebaseFirestore/FIRDocumentChange.h>
#import <FirebaseFirestore/FIRDocumentReference.h>
#import <FirebaseFirestore/FIRSnapshotMetadata.h>

#include <string>
#include <utility>
#include <vector>

#import "Firestore/Example/Tests/Util/FSTHelpers.h"
#import "Firestore/Source/API/FIRCollectionReference+Internal.h"
#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FIRDocumentSnapshot+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRQuerySnapshot+Internal.h"
#import "Firestore/Source/API/FIRSnapshotMetadata+Internal.h"
#import "Firestore/Source/API/FSTUserDataConverter.h"

#include "Firestore/core/src/core/view_snapshot.h"
#include "Firestore/core/src/model/document.h"
#include "Firestore/core/src/model/document_set.h"
#include "Firestore/core/src/remote/firebase_metadata_provider.h"
#include "Firestore/core/src/util/string_apple.h"
#include "Firestore/core/test/unit/testutil/testutil.h"

namespace testutil = firebase::firestore::testutil;
namespace util = firebase::firestore::util;
using firebase::firestore::api::SnapshotMetadata;
using firebase::firestore::core::DocumentViewChange;
using firebase::firestore::core::ViewSnapshot;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::Document;
using firebase::firestore::model::DocumentComparator;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentSet;
using firebase::firestore::model::DocumentState;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::NoDocument;

using testutil::Doc;
using testutil::Query;

NS_ASSUME_NONNULL_BEGIN

FIRFirestore *FSTTestFirestore() {
  static FIRFirestore *sharedInstance = nil;
  static dispatch_once_t onceToken;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  dispatch_once(&onceToken, ^{
    sharedInstance = [[FIRFirestore alloc] initWithDatabaseID:DatabaseId("abc", "abc")
                                               persistenceKey:"db123"
                                          credentialsProvider:nullptr
                                                  workerQueue:nullptr
                                     firebaseMetadataProvider:nullptr
                                                  firebaseApp:nil
                                             instanceRegistry:nil];
  });
#pragma clang diagnostic pop
  return sharedInstance;
}

FIRDocumentSnapshot *FSTTestDocSnapshot(const char *path,
                                        FSTTestSnapshotVersion version,
                                        NSDictionary<NSString *, id> *_Nullable data,
                                        BOOL hasMutations,
                                        BOOL fromCache) {
  absl::optional<Document> doc;
  if (data) {
    FSTUserDataConverter *converter = FSTTestUserDataConverter();
    FieldValue parsed = [converter parsedQueryValue:data];

    doc = Doc(path, version, parsed,
              hasMutations ? DocumentState::kLocalMutations : DocumentState::kSynced);
  }
  return [[FIRDocumentSnapshot alloc] initWithFirestore:FSTTestFirestore().wrapped
                                            documentKey:testutil::Key(path)
                                               document:doc
                                              fromCache:fromCache
                                       hasPendingWrites:hasMutations];
}

FIRCollectionReference *FSTTestCollectionRef(const char *path) {
  return [[FIRCollectionReference alloc] initWithPath:testutil::Resource(path)
                                            firestore:FSTTestFirestore().wrapped];
}

FIRDocumentReference *FSTTestDocRef(const char *path) {
  return [[FIRDocumentReference alloc] initWithPath:testutil::Resource(path)
                                          firestore:FSTTestFirestore().wrapped];
}

/** A convenience method for creating a query snapshots for tests. */
FIRQuerySnapshot *FSTTestQuerySnapshot(
    const char *path,
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *oldDocs,
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *docsToAdd,
    BOOL hasPendingWrites,
    BOOL fromCache) {
  FSTUserDataConverter *converter = FSTTestUserDataConverter();

  SnapshotMetadata metadata(hasPendingWrites, fromCache);
  DocumentSet oldDocuments(DocumentComparator::ByKey());
  DocumentKeySet mutatedKeys;
  for (NSString *key in oldDocs) {
    FieldValue doc = [converter parsedQueryValue:oldDocs[key]];
    std::string documentKey = util::StringFormat("%s/%s", path, key);
    oldDocuments = oldDocuments.insert(
        Doc(documentKey, 1, doc,
            hasPendingWrites ? DocumentState::kLocalMutations : DocumentState::kSynced));
    if (hasPendingWrites) {
      mutatedKeys = mutatedKeys.insert(testutil::Key(documentKey));
    }
  }

  DocumentSet newDocuments = oldDocuments;
  std::vector<DocumentViewChange> documentChanges;
  for (NSString *key in docsToAdd) {
    FieldValue doc = [converter parsedQueryValue:docsToAdd[key]];
    std::string documentKey = util::StringFormat("%s/%s", path, key);
    Document docToAdd =
        Doc(documentKey, 1, doc,
            hasPendingWrites ? DocumentState::kLocalMutations : DocumentState::kSynced);
    newDocuments = newDocuments.insert(docToAdd);
    documentChanges.emplace_back(docToAdd, DocumentViewChange::Type::Added);
    if (hasPendingWrites) {
      mutatedKeys = mutatedKeys.insert(testutil::Key(documentKey));
    }
  }
  ViewSnapshot viewSnapshot{Query(path),
                            newDocuments,
                            oldDocuments,
                            std::move(documentChanges),
                            mutatedKeys,
                            static_cast<bool>(fromCache),
                            /*sync_state_changed=*/true,
                            /*excludes_metadata_changes=*/false};
  return [[FIRQuerySnapshot alloc] initWithFirestore:FSTTestFirestore().wrapped
                                       originalQuery:Query(path)
                                            snapshot:std::move(viewSnapshot)
                                            metadata:std::move(metadata)];
}

NS_ASSUME_NONNULL_END
