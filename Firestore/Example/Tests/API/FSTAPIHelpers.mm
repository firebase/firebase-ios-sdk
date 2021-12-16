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
#import "Firestore/Source/API/FSTUserDataReader.h"

#include "Firestore/core/src/core/view_snapshot.h"
#include "Firestore/core/src/model/document.h"
#include "Firestore/core/src/model/document_set.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/remote/firebase_metadata_provider.h"
#include "Firestore/core/src/util/string_apple.h"
#include "Firestore/core/test/unit/testutil/testutil.h"

using firebase::firestore::api::SnapshotMetadata;
using firebase::firestore::core::DocumentViewChange;
using firebase::firestore::core::ViewSnapshot;
using firebase::firestore::google_firestore_v1_Value;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::Document;
using firebase::firestore::model::DocumentComparator;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentSet;
using firebase::firestore::model::MutableDocument;
using firebase::firestore::nanopb::Message;
using firebase::firestore::testutil::Doc;
using firebase::firestore::testutil::Key;
using firebase::firestore::testutil::Query;
using firebase::firestore::testutil::Resource;
using firebase::firestore::util::StringFormat;

NS_ASSUME_NONNULL_BEGIN

FIRFirestore *FSTTestFirestore() {
  static FIRFirestore *sharedInstance = nil;
  static dispatch_once_t onceToken;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  dispatch_once(&onceToken, ^{
    sharedInstance = [[FIRFirestore alloc] initWithDatabaseID:DatabaseId("abc", "abc")
                                               persistenceKey:"db123"
                                      authCredentialsProvider:nullptr
                                  appCheckCredentialsProvider:nullptr
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
  absl::optional<MutableDocument> doc;
  if (data) {
    FSTUserDataReader *reader = FSTTestUserDataReader();
    Message<google_firestore_v1_Value> parsed = [reader parsedQueryValue:data];

    doc = Doc(path, version, std::move(parsed));
    if (hasMutations) doc->SetHasLocalMutations();
  }
  return [[FIRDocumentSnapshot alloc] initWithFirestore:FSTTestFirestore()
                                            documentKey:Key(path)
                                               document:doc
                                              fromCache:fromCache
                                       hasPendingWrites:hasMutations];
}

FIRCollectionReference *FSTTestCollectionRef(const char *path) {
  return [[FIRCollectionReference alloc] initWithPath:Resource(path)
                                            firestore:FSTTestFirestore().wrapped];
}

FIRDocumentReference *FSTTestDocRef(const char *path) {
  return [[FIRDocumentReference alloc] initWithPath:Resource(path)
                                          firestore:FSTTestFirestore().wrapped];
}

/** A convenience method for creating a query snapshots for tests. */
FIRQuerySnapshot *FSTTestQuerySnapshot(
    const char *path,
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *oldDocs,
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *docsToAdd,
    BOOL hasPendingWrites,
    BOOL fromCache) {
  FSTUserDataReader *reader = FSTTestUserDataReader();

  SnapshotMetadata metadata(hasPendingWrites, fromCache);
  DocumentSet oldDocuments(DocumentComparator::ByKey());
  DocumentKeySet mutatedKeys;
  for (NSString *key in oldDocs) {
    Message<google_firestore_v1_Value> value = [reader parsedQueryValue:oldDocs[key]];
    std::string documentKey = StringFormat("%s/%s", path, key);
    MutableDocument doc = Doc(documentKey, 1, std::move(value));
    if (hasPendingWrites) {
      mutatedKeys = mutatedKeys.insert(Key(documentKey));
      doc.SetHasLocalMutations();
    }
    oldDocuments = oldDocuments.insert(doc);
  }

  DocumentSet newDocuments = oldDocuments;
  std::vector<DocumentViewChange> documentChanges;
  for (NSString *key in docsToAdd) {
    Message<google_firestore_v1_Value> value = [reader parsedQueryValue:docsToAdd[key]];
    std::string documentKey = StringFormat("%s/%s", path, key);
    MutableDocument doc = Doc(documentKey, 1, std::move(value));
    documentChanges.emplace_back(doc, DocumentViewChange::Type::Added);
    if (hasPendingWrites) {
      mutatedKeys = mutatedKeys.insert(Key(documentKey));
      doc.SetHasLocalMutations();
    }
    newDocuments = newDocuments.insert(doc);
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
