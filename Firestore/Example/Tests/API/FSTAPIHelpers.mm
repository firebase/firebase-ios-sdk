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

#import "Firestore/Source/API/FIRCollectionReference+Internal.h"
#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FIRDocumentSnapshot+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRQuerySnapshot+Internal.h"
#import "Firestore/Source/API/FIRSnapshotMetadata+Internal.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTViewSnapshot.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"

#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

namespace testutil = firebase::firestore::testutil;
namespace util = firebase::firestore::util;

NS_ASSUME_NONNULL_BEGIN

FIRFirestore *FSTTestFirestore() {
  static FIRFirestore *sharedInstance = nil;
  static dispatch_once_t onceToken;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  dispatch_once(&onceToken, ^{
    sharedInstance = [[FIRFirestore alloc] initWithProjectID:"abc"
                                                    database:"abc"
                                              persistenceKey:@"db123"
                                         credentialsProvider:nil
                                         workerDispatchQueue:nil
                                                 firebaseApp:nil];
  });
#pragma clang diagnostic pop
  return sharedInstance;
}

FIRDocumentSnapshot *FSTTestDocSnapshot(const absl::string_view path,
                                        FSTTestSnapshotVersion version,
                                        NSDictionary<NSString *, id> *_Nullable data,
                                        BOOL hasMutations,
                                        BOOL fromCache) {
  FSTDocument *doc = data ? FSTTestDoc(path, version, data, hasMutations) : nil;
  return [FIRDocumentSnapshot snapshotWithFirestore:FSTTestFirestore()
                                        documentKey:testutil::Key(path)
                                           document:doc
                                          fromCache:fromCache];
}

FIRCollectionReference *FSTTestCollectionRef(const absl::string_view path) {
  return [FIRCollectionReference referenceWithPath:testutil::Resource(path)
                                         firestore:FSTTestFirestore()];
}

FIRDocumentReference *FSTTestDocRef(const absl::string_view path) {
  return [FIRDocumentReference referenceWithPath:testutil::Resource(path)
                                       firestore:FSTTestFirestore()];
}

/** A convenience method for creating a query snapshots for tests. */
FIRQuerySnapshot *FSTTestQuerySnapshot(
    const absl::string_view path,
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *oldDocs,
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *docsToAdd,
    BOOL hasPendingWrites,
    BOOL fromCache) {
  FIRSnapshotMetadata *metadata =
      [FIRSnapshotMetadata snapshotMetadataWithPendingWrites:hasPendingWrites fromCache:fromCache];
  FSTDocumentSet *oldDocuments = FSTTestDocSet(FSTDocumentComparatorByKey, @[]);
  for (NSString *key in oldDocs) {
    oldDocuments = [oldDocuments
        documentSetByAddingDocument:FSTTestDoc(util::MakeStringView([NSString
                                                   stringWithFormat:@"%s/%@", path.data(), key]),
                                               1, oldDocs[key], hasPendingWrites)];
  }
  FSTDocumentSet *newDocuments = oldDocuments;
  NSArray<FSTDocumentViewChange *> *documentChanges = [NSArray array];
  for (NSString *key in docsToAdd) {
    FSTDocument *docToAdd =
        FSTTestDoc(util::MakeStringView([NSString stringWithFormat:@"%s/%@", path.data(), key]), 1,
                   docsToAdd[key], hasPendingWrites);
    newDocuments = [newDocuments documentSetByAddingDocument:docToAdd];
    documentChanges = [documentChanges
        arrayByAddingObject:[FSTDocumentViewChange
                                changeWithDocument:docToAdd
                                              type:FSTDocumentViewChangeTypeAdded]];
  }
  FSTViewSnapshot *viewSnapshot = [[FSTViewSnapshot alloc] initWithQuery:FSTTestQuery(path)
                                                               documents:newDocuments
                                                            oldDocuments:oldDocuments
                                                         documentChanges:documentChanges
                                                               fromCache:fromCache
                                                        hasPendingWrites:hasPendingWrites
                                                        syncStateChanged:YES];
  return [FIRQuerySnapshot snapshotWithFirestore:FSTTestFirestore()
                                   originalQuery:FSTTestQuery(path)
                                        snapshot:viewSnapshot
                                        metadata:metadata];
}

NS_ASSUME_NONNULL_END
