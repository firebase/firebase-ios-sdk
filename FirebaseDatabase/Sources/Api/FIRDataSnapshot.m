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

#import "FIRDataSnapshot.h"
#import "FChildrenNode.h"
#import "FIRDataSnapshot_Private.h"
#import "FIRDatabaseReference.h"
#import "FTransformedEnumerator.h"
#import "FValidation.h"

@interface FIRDataSnapshot ()
@property(nonatomic, strong) FIRDatabaseReference *ref;
@end

@implementation FIRDataSnapshot

- (id)initWithRef:(FIRDatabaseReference *)ref indexedNode:(FIndexedNode *)node {
    self = [super init];
    if (self != nil) {
        self->_ref = ref;
        self->_node = node;
    }
    return self;
}

- (id)value {
    return [self.node.node val];
}

- (id)valueInExportFormat {
    return [self.node.node valForExport:YES];
}

- (FIRDataSnapshot *)childSnapshotForPath:(NSString *)childPathString {
    [FValidation validateFrom:@"child:" validPathString:childPathString];
    FPath *childPath = [[FPath alloc] initWith:childPathString];
    FIRDatabaseReference *childRef = [self.ref child:childPathString];

    id<FNode> childNode = [self.node.node getChild:childPath];
    return [[FIRDataSnapshot alloc]
        initWithRef:childRef
        indexedNode:[FIndexedNode indexedNodeWithNode:childNode]];
}

- (BOOL)hasChild:(NSString *)childPathString {
    [FValidation validateFrom:@"hasChild:" validPathString:childPathString];
    FPath *childPath = [[FPath alloc] initWith:childPathString];
    return ![[self.node.node getChild:childPath] isEmpty];
}

- (id)priority {
    id<FNode> priority = [self.node.node getPriority];
    return priority.val;
}

- (BOOL)hasChildren {
    if ([self.node.node isLeafNode]) {
        return false;
    } else {
        return ![self.node.node isEmpty];
    }
}

- (BOOL)exists {
    return ![self.node.node isEmpty];
}

- (NSString *)key {
    return [self.ref key];
}

- (NSUInteger)childrenCount {
    return [self.node.node numChildren];
}

- (NSEnumerator<FIRDataSnapshot *> *)children {
    return [[FTransformedEnumerator alloc]
        initWithEnumerator:self.node.childEnumerator
              andTransform:^id(FNamedNode *node) {
                FIRDatabaseReference *childRef = [self.ref child:node.name];
                return [[FIRDataSnapshot alloc]
                    initWithRef:childRef
                    indexedNode:[FIndexedNode indexedNodeWithNode:node.node]];
              }];
}

- (NSString *)description {
    return
        [NSString stringWithFormat:@"Snap (%@) %@", self.key, self.node.node];
}

@end
