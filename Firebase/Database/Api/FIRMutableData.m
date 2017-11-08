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

#import "FIRMutableData.h"
#import "FIRMutableData_Private.h"
#import "FSnapshotHolder.h"
#import "FSnapshotUtilities.h"
#import "FChildrenNode.h"
#import "FTransformedEnumerator.h"
#import "FNamedNode.h"
#import "FIndexedNode.h"

@interface FIRMutableData ()

- (id) initWithPrefixPath:(FPath *)path andSnapshotHolder:(FSnapshotHolder *)snapshotHolder;

@property (strong, nonatomic) FSnapshotHolder* data;
@property (strong, nonatomic) FPath* prefixPath;

@end

@implementation FIRMutableData

@synthesize data;
@synthesize prefixPath;

- (id) initWithNode:(id<FNode>)node {
    FSnapshotHolder* holder = [[FSnapshotHolder alloc] init];
    FPath* path = [FPath empty];
    [holder updateSnapshot:path withNewSnapshot:node];
    return [self initWithPrefixPath:path andSnapshotHolder:holder];
}

- (id) initWithPrefixPath:(FPath *)path andSnapshotHolder:(FSnapshotHolder *)snapshotHolder {
    self = [super init];
    if (self) {
        self.prefixPath = path;
        self.data = snapshotHolder;
    }
    return self;
}

- (FIRMutableData *)childDataByAppendingPath:(NSString *)path {
    FPath* wholePath = [self.prefixPath childFromString:path];
    return [[FIRMutableData alloc] initWithPrefixPath:wholePath andSnapshotHolder:self.data];
}

- (FIRMutableData *) parent {
    if ([self.prefixPath isEmpty]) {
        return nil;
    } else {
        FPath* path = [self.prefixPath parent];
        return [[FIRMutableData alloc] initWithPrefixPath:path andSnapshotHolder:self.data];
    }
}

- (void) setValue:(id)aValue {
    id<FNode> node = [FSnapshotUtilities nodeFrom:aValue withValidationFrom:@"setValue:"];
    [self.data updateSnapshot:self.prefixPath withNewSnapshot:node];
}

- (void) setPriority:(id)aPriority {
    id<FNode> node = [self.data getNode:self.prefixPath];
    id<FNode> pri = [FSnapshotUtilities nodeFrom:aPriority];
    node = [node updatePriority:pri];
    [self.data updateSnapshot:self.prefixPath withNewSnapshot:node];
}

- (id) value {
    return [[self.data getNode:self.prefixPath] val];
}

- (id) priority {
    return [[[self.data getNode:self.prefixPath] getPriority] val];
}

- (BOOL) hasChildren {
    id<FNode> node = [self.data getNode:self.prefixPath];
    return ![node isLeafNode] && ![(FChildrenNode*)node isEmpty];
}

- (BOOL) hasChildAtPath:(NSString *)path {
    id<FNode> node = [self.data getNode:self.prefixPath];
    FPath* childPath = [[FPath alloc] initWith:path];
    return ![[node getChild:childPath] isEmpty];
}

- (NSUInteger) childrenCount {
    return [[self.data getNode:self.prefixPath] numChildren];
}

- (NSString *) key {
    return [self.prefixPath getBack];
}

- (id<FNode>) nodeValue {
    return [self.data getNode:self.prefixPath];
}

- (NSEnumerator<FIRMutableData *> *) children {
    FIndexedNode *indexedNode = [FIndexedNode indexedNodeWithNode:self.nodeValue];
    return [[FTransformedEnumerator alloc] initWithEnumerator:[indexedNode childEnumerator] andTransform:^id(FNamedNode *node) {
        FPath* childPath = [self.prefixPath childFromString:node.name];
        FIRMutableData * childData = [[FIRMutableData alloc] initWithPrefixPath:childPath andSnapshotHolder:self.data];
        return childData;
    }];
}

- (BOOL) isEqualToData:(FIRMutableData *)other {
    return self.data == other.data && [[self.prefixPath description] isEqualToString:[other.prefixPath description]];
}

- (NSString *) description {
    if (self.key == nil) {
        return [NSString stringWithFormat:@"FIRMutableData (top-most transaction) %@ %@", self.key, self.value];
    } else {
        return [NSString stringWithFormat:@"FIRMutableData (%@) %@", self.key, self.value];
    }
}

@end
