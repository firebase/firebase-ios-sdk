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

#import "FOperation.h"

@class FPath;
@class FOperationSource;
@class FImmutableTree;


@interface FAckUserWrite : NSObject <FOperation>

- initWithPath:(FPath *)operationPath affectedTree:(FImmutableTree *)affectedTree revert:(BOOL)shouldRevert;

@property (nonatomic, strong, readonly) FOperationSource *source;
@property (nonatomic, readonly) FOperationType type;
@property (nonatomic, strong, readonly) FPath *path;
// A FImmutableTree, containing @YES for each affected path.  Affected paths can't overlap.
@property (nonatomic, strong, readonly) FImmutableTree *affectedTree;
@property (nonatomic, readonly) BOOL revert;

@end
