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

#import "FirebaseDatabase/Sources/Core/FSparseSnapshotTree.h"
#import "FirebaseDatabase/Sources/Core/FSyncTree.h"
#import "FirebaseDatabase/Sources/FClock.h"
#import "FirebaseDatabase/Sources/Snapshot/FCompoundWrite.h"
#import "FirebaseDatabase/Sources/Snapshot/FNode.h"
#import <Foundation/Foundation.h>

@interface FServerValues : NSObject

+ (NSDictionary *)generateServerValues:(id<FClock>)clock;

+ (FCompoundWrite *)resolveDeferredValueCompoundWrite:(FCompoundWrite *)write
                                         withSyncTree:(FSyncTree *)tree
                                               atPath:(FPath *)path
                                         serverValues:
                                             (NSDictionary *)serverValues;
+ (id<FNode>)resolveDeferredValueSnapshot:(id<FNode>)node
                             withSyncTree:(FSyncTree *)existing
                                   atPath:(FPath *)path
                             serverValues:(NSDictionary *)serverValues;
+ (id<FNode>)resolveDeferredValueSnapshot:(id<FNode>)node
                             withExisting:(id<FNode>)existing
                             serverValues:(NSDictionary *)serverValues;
@end
