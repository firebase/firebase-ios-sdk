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

#import "FIRDocumentChange.h"

#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"

@class FIRFirestore;

NS_ASSUME_NONNULL_BEGIN

/** Internal FIRDocumentChange API we don't want exposed in our public header files. */
@interface FIRDocumentChange (Internal)

/** Calculates the array of FIRDocumentChange's based on the given FSTViewSnapshot. */
+ (NSArray<FIRDocumentChange *> *)documentChangesForSnapshot:
                                      (const firebase::firestore::core::ViewSnapshot &)snapshot
                                      includeMetadataChanges:(BOOL)includeMetadataChanges
                                                   firestore:(FIRFirestore *)firestore;

@end

NS_ASSUME_NONNULL_END
