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
#import <XCTest/XCTest.h>
#import "FirebaseDatabase/Sources/Api/Private/FIRDatabaseReference_Private.h"
#import "FirebaseDatabase/Sources/Core/FRepoManager.h"
#import "FirebaseDatabase/Sources/Snapshot/FSnapshotUtilities.h"
#import "FirebaseDatabase/Sources/Utilities/Tuples/FTupleFirebase.h"
#import "FirebaseDatabase/Tests/Helpers/FTestContants.h"

#define WAIT_FOR(x)   \
  [self waitUntil:^{  \
    return (BOOL)(x); \
  }];

#define NODE(__node) [FSnapshotUtilities nodeFrom:(__node)]
#define PATH(__path) [FPath pathWithString:(__path)]

@interface FTestHelpers : XCTestCase
+ (NSString *)databaseURL;
+ (FIRDatabaseConfig *)defaultConfig;
+ (FIRDatabaseConfig *)configForName:(NSString *)name;
+ (FIRDatabase *)defaultDatabase;
+ (FIRDatabase *)databaseForConfig:(FIRDatabaseConfig *)config;
+ (FIRDatabaseReference *)getRandomNode;
+ (FIRDatabaseReference *)getRandomNodeWithoutPersistence;
+ (FTupleFirebase *)getRandomNodePair;
+ (FTupleFirebase *)getRandomNodePairWithoutPersistence;
+ (FTupleFirebase *)getRandomNodeTriple;
+ (id<FNode>)leafNodeOfSize:(NSUInteger)size;

@end
