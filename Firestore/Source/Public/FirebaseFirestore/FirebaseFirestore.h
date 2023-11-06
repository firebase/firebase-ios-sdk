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

#import <FirebaseFirestore/FIRAggregateField.h>
#import <FirebaseFirestore/FIRAggregateQuery.h>
#import <FirebaseFirestore/FIRAggregateQuerySnapshot.h>
#import <FirebaseFirestore/FIRAggregateSource.h>
#import <FirebaseFirestore/FIRCollectionReference.h>
#import <FirebaseFirestore/FIRDocumentChange.h>
#import <FirebaseFirestore/FIRDocumentReference.h>
#import <FirebaseFirestore/FIRDocumentSnapshot.h>
#import <FirebaseFirestore/FIRFieldPath.h>
#import <FirebaseFirestore/FIRFieldValue.h>
#import <FirebaseFirestore/FIRFilter.h>
#import <FirebaseFirestore/FIRFirestore.h>
#import <FirebaseFirestore/FIRFirestoreErrors.h>
#import <FirebaseFirestore/FIRFirestoreSettings.h>
#import <FirebaseFirestore/FIRGeoPoint.h>
#import <FirebaseFirestore/FIRListenerRegistration.h>
#import <FirebaseFirestore/FIRLoadBundleTask.h>
#import <FirebaseFirestore/FIRLocalCacheSettings.h>
#import <FirebaseFirestore/FIRQuery.h>
#import <FirebaseFirestore/FIRQuerySnapshot.h>
#import <FirebaseFirestore/FIRSnapshotMetadata.h>
#import <FirebaseFirestore/FIRTimestamp.h>
#import <FirebaseFirestore/FIRTransaction.h>
#import <FirebaseFirestore/FIRTransactionOptions.h>
#import <FirebaseFirestore/FIRWriteBatch.h>
