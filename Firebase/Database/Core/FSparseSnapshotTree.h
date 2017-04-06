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
#import "FNode.h"
#import "FPath.h"
#import "FTypedefs_Private.h"

@class FSparseSnapshotTree;

typedef void (^fbt_void_nsstring_sstree) (NSString*, FSparseSnapshotTree*);

@interface FSparseSnapshotTree : NSObject

- (id<FNode>) findPath:(FPath *)path;
- (void) rememberData:(id<FNode>)data onPath:(FPath *)path;
- (BOOL) forgetPath:(FPath *)path;
- (void) forEachTreeAtPath:(FPath *)prefixPath do:(fbt_void_path_node)func;
- (void) forEachChild:(fbt_void_nsstring_sstree)func;

@end
