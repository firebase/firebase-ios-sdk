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

#import "FIRDocumentSnapshot.h"

#import <Foundation/Foundation.h>

#import "Firestore/Source/Model/FSTFieldValue.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRSnapshotOptions (Internal)

/** Returns a default instance of FIRSnapshotOptions that specifies no options. */
+ (instancetype)defaultOptions;

/* Initializes a new instance with the specified server timestamp behavior. */
- (instancetype)initWithServerTimestampBehavior:(FSTServerTimestampBehavior)serverTimestampBehavior;

/* Returns the server timestamp behavior. Returns -1 if no behavior is specified. */
- (FSTServerTimestampBehavior)serverTimestampBehavior;

@end

NS_ASSUME_NONNULL_END
