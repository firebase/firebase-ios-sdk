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

#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/Core/FSTTypes.h"
#import "Firestore/Source/Model/FSTDocumentDictionary.h"
#import "Firestore/Source/Model/FSTDocumentKeySet.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

@class FIRCollectionReference;
@class FIRDocumentReference;
@class FIRDocumentSnapshot;
@class FIRFirestore;
@class FIRGeoPoint;
@class FIRQuerySnapshot;
@class FSTDeleteMutation;
@class FSTDeletedDocument;
@class FSTDocument;
@class FSTDocumentKeyReference;
@class FSTDocumentSet;
@class FSTFieldPath;
@class FSTFieldValue;
@class FSTLocalViewChanges;
@class FSTPatchMutation;
@class FSTQuery;
@class FSTRemoteEvent;
@class FSTResourceName;
@class FSTResourcePath;
@class FSTSetMutation;
@class FSTSnapshotVersion;
@class FSTSortOrder;
@class FSTTargetChange;
@class FSTTimestamp;
@class FSTTransformMutation;
@class FSTView;
@class FSTViewSnapshot;
@class FSTObjectValue;
@protocol FSTFilter;

NS_ASSUME_NONNULL_BEGIN

#if __cplusplus
extern "C" {
#endif

/** A convenience method for creating dummy singleton FIRFirestore for tests. */
FIRFirestore *FSTTestFirestore();

/** Creates a new GeoPoint from the latitude and longitude values */
FIRGeoPoint *FSTTestGeoPoint(double latitude, double longitude);

/** A convenience method for creating a doc snapshot for tests. */
FIRDocumentSnapshot *FSTTestDocSnapshot(NSString *path,
                                        FSTTestSnapshotVersion version,
                                        NSDictionary<NSString *, id> *data,
                                        BOOL hasMutations,
                                        BOOL fromCache);

/** A covenience method for creating a collection reference from a path string. */
FIRCollectionReference *FSTTestCollectionRef(NSString *path);

/** A covenience method for creating a document reference from a path string. */
FIRDocumentReference *FSTTestDocRef(NSString *path);

/**
 * A convenience method for creating a particular query snapshot for tests.
 * This function allows user to pass in snapshot of the query in the past as well as new rows to be
 * added into the snapshot as for now. The current snapshot of the query consists both data.
 */
FIRQuerySnapshot *FSTTestQuerySnapshot(
    NSString *path,
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *oldData,
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *dataToAdd,
    BOOL hasPendingWrites,
    BOOL fromCache);

#if __cplusplus
}  // extern "C"
#endif

NS_ASSUME_NONNULL_END
