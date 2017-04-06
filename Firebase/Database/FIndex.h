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

@class FImmutableSortedDictionary;
@class FNamedNode;
@protocol FNode;

@protocol FIndex<NSObject, NSCopying>
- (NSComparisonResult) compareKey:(NSString *)key1
                          andNode:(id<FNode>)node1
                       toOtherKey:(NSString *)key2
                          andNode:(id<FNode>)node2;

- (NSComparisonResult) compareKey:(NSString *)key1
                          andNode:(id<FNode>)node1
                       toOtherKey:(NSString *)key2
                          andNode:(id<FNode>)node2
                          reverse:(BOOL)reverse;

- (NSComparisonResult) compareNamedNode:(FNamedNode *)namedNode1 toNamedNode:(FNamedNode *)namedNode2;

- (BOOL) isDefinedOn:(id<FNode>)node;
- (BOOL) indexedValueChangedBetween:(id<FNode>)oldNode and:(id<FNode>)newNode;
- (FNamedNode*) minPost;
- (FNamedNode*) maxPost;
- (FNamedNode*) makePost:(id<FNode>)indexValue name:(NSString*)name;
- (NSString*) queryDefinition;

@end

@interface FIndex : NSObject

+ (id<FIndex>)indexFromQueryDefinition:(NSString *)string;

@end
