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

@import FirebaseFirestore;

#import <XCTest/XCTest.h>

#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRQuery+Internal.h"
#import "Firestore/Source/API/FIRQuerySnapshot+Internal.h"
#import "Firestore/Source/API/FIRSnapshotMetadata+Internal.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTSnapshotVersion.h"
#import "Firestore/Source/Core/FSTViewSnapshot.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"
#import "Firestore/Source/Model/FSTFieldValue.h"
#import "Firestore/Source/Model/FSTPath.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRQuerySnapshotTests : XCTestCase
@end

@implementation FIRQuerySnapshotTests

- (void)testEquals {
  // Everything is dummy for unit test here. Filtering does not require any app
  // specific setting as far as we do not fetch data.
  FIRFirestore *firestore = [[FIRFirestore alloc] initWithProjectID:@"abc"
                                                           database:@"abc"
                                                     persistenceKey:@"db123"
                                                credentialsProvider:nil
                                                workerDispatchQueue:nil
                                                        firebaseApp:nil];
  FSTResourcePath *pathFoo = [FSTResourcePath pathWithString:@"foo"];
  FSTResourcePath *pathBar = [FSTResourcePath pathWithString:@"bar"];
  FSTQuery *queryFoo = [FSTQuery queryWithPath:pathFoo];
  FSTQuery *queryBar = [FSTQuery queryWithPath:pathBar];
  FIRSnapshotMetadata *metadataFoo =
      [FIRSnapshotMetadata snapshotMetadataWithPendingWrites:YES fromCache:YES];
  FIRSnapshotMetadata *metadataBar =
      [FIRSnapshotMetadata snapshotMetadataWithPendingWrites:NO fromCache:NO];
  FSTDocumentSet *documents = [FSTDocumentSet documentSetWithComparator:FSTDocumentComparatorByKey];
  FSTDocumentSet *oldDocuments = documents;
  documents = [documents documentSetByAddingDocument:FSTTestDoc(@"c/a", 1, @{}, NO)];
  NSArray<FSTDocumentViewChange *> *documentChanges =
      @[ [FSTDocumentViewChange changeWithDocument:FSTTestDoc(@"c/a", 1, @{}, NO)
                                              type:FSTDocumentViewChangeTypeAdded] ];
  FSTViewSnapshot *snapshotFoo = [[FSTViewSnapshot alloc] initWithQuery:queryFoo
                                                              documents:documents
                                                           oldDocuments:oldDocuments
                                                        documentChanges:documentChanges
                                                              fromCache:YES
                                                       hasPendingWrites:NO
                                                       syncStateChanged:YES];
  FSTViewSnapshot *snapshotBar = [[FSTViewSnapshot alloc] initWithQuery:queryBar
                                                              documents:documents
                                                           oldDocuments:oldDocuments
                                                        documentChanges:documentChanges
                                                              fromCache:YES
                                                       hasPendingWrites:NO
                                                       syncStateChanged:YES];
  XCTAssertEqualObjects([FIRQuerySnapshot snapshotWithFirestore:firestore
                                                  originalQuery:queryFoo
                                                       snapshot:snapshotFoo
                                                       metadata:metadataFoo],
                        [FIRQuerySnapshot snapshotWithFirestore:firestore
                                                  originalQuery:queryFoo
                                                       snapshot:snapshotFoo
                                                       metadata:metadataFoo]);
  XCTAssertNotEqualObjects([FIRQuerySnapshot snapshotWithFirestore:firestore
                                                     originalQuery:queryFoo
                                                          snapshot:snapshotFoo
                                                          metadata:metadataFoo],
                           [FIRQuerySnapshot snapshotWithFirestore:firestore
                                                     originalQuery:queryBar
                                                          snapshot:snapshotFoo
                                                          metadata:metadataFoo]);
  XCTAssertNotEqualObjects([FIRQuerySnapshot snapshotWithFirestore:firestore
                                                     originalQuery:queryFoo
                                                          snapshot:snapshotFoo
                                                          metadata:metadataFoo],
                           [FIRQuerySnapshot snapshotWithFirestore:firestore
                                                     originalQuery:queryFoo
                                                          snapshot:snapshotBar
                                                          metadata:metadataFoo]);
  XCTAssertNotEqualObjects([FIRQuerySnapshot snapshotWithFirestore:firestore
                                                     originalQuery:queryFoo
                                                          snapshot:snapshotFoo
                                                          metadata:metadataFoo],
                           [FIRQuerySnapshot snapshotWithFirestore:firestore
                                                     originalQuery:queryFoo
                                                          snapshot:snapshotFoo
                                                          metadata:metadataBar]);
}

@end

NS_ASSUME_NONNULL_END
