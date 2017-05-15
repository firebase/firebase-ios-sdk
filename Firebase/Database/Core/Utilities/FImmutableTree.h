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

#import "FImmutableSortedDictionary.h"
#import "FPath.h"
#import "FTuplePathValue.h"

@interface FImmutableTree : NSObject

- (id) initWithValue:(id)aValue;
- (id) initWithValue:(id)aValue children:(FImmutableSortedDictionary *)childrenMap;

+ (FImmutableTree *) empty;
- (BOOL) isEmpty;

- (FTuplePathValue *) findRootMostMatchingPath:(FPath *)relativePath predicate:(BOOL (^)(id))predicate;
- (FTuplePathValue *) findRootMostValueAndPath:(FPath *)relativePath;
- (FImmutableTree *) subtreeAtPath:(FPath *)relativePath;
- (FImmutableTree *) setValue:(id)newValue atPath:(FPath *)relativePath;
- (FImmutableTree *) removeValueAtPath:(FPath *)relativePath;
- (id) valueAtPath:(FPath *)relativePath;
- (id) rootMostValueOnPath:(FPath *)path;
- (id) rootMostValueOnPath:(FPath *)path matching:(BOOL (^)(id))predicate;
- (id) leafMostValueOnPath:(FPath *)path;
- (id) leafMostValueOnPath:(FPath *)relativePath matching:(BOOL (^)(id))predicate;
- (BOOL) containsValueMatching:(BOOL (^)(id))predicate;
- (FImmutableTree *) setTree:(FImmutableTree *)newTree atPath:(FPath *)relativePath;
- (id) foldWithBlock:(id (^)(FPath *path, id value, NSDictionary *foldedChildren))block;
- (id) findOnPath:(FPath *)path andApplyBlock:(id (^)(FPath *path, id value))block;
- (FPath *) forEachOnPath:(FPath *)path whileBlock:(BOOL (^)(FPath *path, id value))block;
- (FImmutableTree *) forEachOnPath:(FPath *)path performBlock:(void (^)(FPath *path, id value))block;
- (void) forEach:(void (^)(FPath *path, id value))block;
- (void) forEachChild:(void (^)(NSString *childKey, id childValue))block;

@property (nonatomic, strong, readonly) id value;
@property (nonatomic, strong, readonly) FImmutableSortedDictionary *children;

@end
