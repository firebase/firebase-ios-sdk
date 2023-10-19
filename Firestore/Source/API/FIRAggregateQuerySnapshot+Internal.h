/*
 * Copyright 2022 Google LLC
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

#import "FIRAggregateQuerySnapshot.h"

#import "FIRAggregateField.h"
#import "FIRDocumentSnapshot.h"

#include "Firestore/core/src/api/api_fwd.h"

@class FIRAggregateQuery;

namespace model = firebase::firestore::model;

NS_ASSUME_NONNULL_BEGIN

@interface FIRAggregateQuerySnapshot (/* init */)

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithObject:(model::ObjectValue)result
                         query:(FIRAggregateQuery *)query NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
