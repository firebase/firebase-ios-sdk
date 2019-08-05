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

#import "FChange.h"

@interface FChange ()

@property(nonatomic, strong, readwrite) NSString *prevKey;

@end

@implementation FChange

- (id)initWithType:(FIRDataEventType)type
       indexedNode:(FIndexedNode *)indexedNode {
    return [self initWithType:type
                  indexedNode:indexedNode
                     childKey:nil
               oldIndexedNode:nil];
}

- (id)initWithType:(FIRDataEventType)type
       indexedNode:(FIndexedNode *)indexedNode
          childKey:(NSString *)childKey {
    return [self initWithType:type
                  indexedNode:indexedNode
                     childKey:childKey
               oldIndexedNode:nil];
}

- (id)initWithType:(FIRDataEventType)type
       indexedNode:(FIndexedNode *)indexedNode
          childKey:(NSString *)childKey
    oldIndexedNode:(FIndexedNode *)oldIndexedNode {
    self = [super init];
    if (self != nil) {
        self->_type = type;
        self->_indexedNode = indexedNode;
        self->_childKey = childKey;
        self->_oldIndexedNode = oldIndexedNode;
    }
    return self;
}

- (FChange *)changeWithPrevKey:(NSString *)prevKey {
    FChange *newChange = [[FChange alloc] initWithType:self.type
                                           indexedNode:self.indexedNode
                                              childKey:self.childKey
                                        oldIndexedNode:self.oldIndexedNode];
    newChange.prevKey = prevKey;
    return newChange;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"event: %d, data: %@", (int)self.type,
                                      [self.indexedNode.node val]];
}

@end
