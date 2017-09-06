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

#import "FIRDatabaseReference.h"
#import "FIndexedNode.h"
#import "FNode.h"
#import <Foundation/Foundation.h>

@interface FChange : NSObject

@property(nonatomic, readonly) FIRDataEventType type;
@property(nonatomic, strong, readonly) FIndexedNode *indexedNode;
@property(nonatomic, strong, readonly) NSString *childKey;
@property(nonatomic, strong, readonly) NSString *prevKey;
@property(nonatomic, strong, readonly) FIndexedNode *oldIndexedNode;

- (id)initWithType:(FIRDataEventType)type
       indexedNode:(FIndexedNode *)indexedNode;
- (id)initWithType:(FIRDataEventType)type
       indexedNode:(FIndexedNode *)indexedNode
          childKey:(NSString *)childKey;
- (id)initWithType:(FIRDataEventType)type
       indexedNode:(FIndexedNode *)indexedNode
          childKey:(NSString *)childKey
    oldIndexedNode:(FIndexedNode *)oldIndexedNode;

- (FChange *)changeWithPrevKey:(NSString *)prevKey;
@end
