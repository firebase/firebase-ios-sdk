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

@class FImmutableTree;
@protocol FNode;
@class FPath;

/**
* This class holds a collection of writes that can be applied to nodes in unison. It abstracts away the logic with
* dealing with priority writes and multiple nested writes. At any given path, there is only allowed to be one write
* modifying that path. Any write to an existing path or shadowing an existing path will modify that existing write to
* reflect the write added.
*/
@interface FCompoundWrite : NSObject

- (id) initWithWriteTree:(FImmutableTree *)tree;

/**
 * Creates a compound write with NSDictionary from path string to object
 */
+ (FCompoundWrite *) compoundWriteWithValueDictionary:(NSDictionary *)dictionary;
/**
 * Creates a compound write with NSDictionary from path string to node
 */
+ (FCompoundWrite *) compoundWriteWithNodeDictionary:(NSDictionary *)dictionary;

+ (FCompoundWrite *) emptyWrite;

- (FCompoundWrite *) addWrite:(id<FNode>)node atPath:(FPath *)path;
- (FCompoundWrite *) addWrite:(id<FNode>)node atKey:(NSString *)key;
- (FCompoundWrite *) addCompoundWrite:(FCompoundWrite *)node atPath:(FPath *)path;
- (FCompoundWrite *) removeWriteAtPath:(FPath *)path;
- (id<FNode>)rootWrite;
- (BOOL) hasCompleteWriteAtPath:(FPath *)path;
- (id<FNode>) completeNodeAtPath:(FPath *)path;
- (NSArray *) completeChildren;
- (NSDictionary *)childCompoundWrites;
- (FCompoundWrite *) childCompoundWriteAtPath:(FPath *)path;
- (id<FNode>) applyToNode:(id<FNode>)node;
- (void)enumerateWrites:(void (^)(FPath *path, id<FNode>node, BOOL *stop))block;

- (NSDictionary *)valForExport:(BOOL)exportFormat;

- (BOOL) isEmpty;

@end
