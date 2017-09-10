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

#import "FLeafNode.h"
#import "FChildrenNode.h"
#import "FConstants.h"
#import "FEmptyNode.h"
#import "FImmutableSortedDictionary.h"
#import "FSnapshotUtilities.h"
#import "FStringUtilities.h"
#import "FUtilities.h"

@interface FLeafNode ()
@property(nonatomic, strong) id<FNode> priorityNode;
@property(nonatomic, strong) NSString *lazyHash;

@end

@implementation FLeafNode

@synthesize value;
@synthesize priorityNode;

- (id)initWithValue:(id)aValue {
    self = [super init];
    if (self) {
        self.value = aValue;
        self.priorityNode = [FEmptyNode emptyNode];
    }
    return self;
}

- (id)initWithValue:(id)aValue withPriority:(id<FNode>)aPriority {
    self = [super init];
    if (self) {
        self.value = aValue;
        [FSnapshotUtilities validatePriorityNode:aPriority];
        self.priorityNode = aPriority;
    }
    return self;
}

#pragma mark -
#pragma mark FNode methods

- (BOOL)isLeafNode {
    return YES;
}

- (id<FNode>)getPriority {
    return self.priorityNode;
}

- (id<FNode>)updatePriority:(id<FNode>)aPriority {
    return [[FLeafNode alloc] initWithValue:self.value withPriority:aPriority];
}

- (id<FNode>)getImmediateChild:(NSString *)childName {
    if ([childName isEqualToString:@".priority"]) {
        return self.priorityNode;
    } else {
        return [FEmptyNode emptyNode];
    }
}

- (id<FNode>)getChild:(FPath *)path {
    if (path.getFront == nil) {
        return self;
    } else if ([[path getFront] isEqualToString:@".priority"]) {
        return [self getPriority];
    } else {
        return [FEmptyNode emptyNode];
    }
}

- (BOOL)hasChild:(NSString *)childName {
    return
        [childName isEqualToString:@".priority"] && ![self getPriority].isEmpty;
}

- (NSString *)predecessorChildKey:(NSString *)childKey {
    return nil;
}

- (id<FNode>)updateImmediateChild:(NSString *)childName
                     withNewChild:(id<FNode>)newChildNode {
    if ([childName isEqualToString:@".priority"]) {
        return [self updatePriority:newChildNode];
    } else if (newChildNode.isEmpty) {
        return self;
    } else {
        FChildrenNode *childrenNode = [[FChildrenNode alloc] init];
        childrenNode = [childrenNode updateImmediateChild:childName
                                             withNewChild:newChildNode];
        childrenNode = [childrenNode updatePriority:self.priorityNode];
        return childrenNode;
    }
}

- (id<FNode>)updateChild:(FPath *)path withNewChild:(id<FNode>)newChildNode {
    NSString *front = [path getFront];
    if (front == nil) {
        return newChildNode;
    } else if (newChildNode.isEmpty && ![front isEqualToString:@".priority"]) {
        return self;
    } else {
        NSAssert(![front isEqualToString:@".priority"] || path.length == 1,
                 @".priority must be the last token in a path.");
        return [self updateImmediateChild:front
                             withNewChild:[[FEmptyNode emptyNode]
                                               updateChild:[path popFront]
                                              withNewChild:newChildNode]];
    }
}

- (id)val {
    return [self valForExport:NO];
}

- (id)valForExport:(BOOL)exp {
    if (exp && !self.getPriority.isEmpty) {
        return @{
            kPayloadValue : self.value,
            kPayloadPriority : [[self getPriority] val]
        };
    } else {
        return self.value;
    }
}

- (BOOL)isEqual:(id<FNode>)other {
    if (other == self) {
        return YES;
    } else if (other.isLeafNode) {
        FLeafNode *otherLeaf = other;
        if ([FUtilities getJavascriptType:self.value] !=
            [FUtilities getJavascriptType:otherLeaf.value]) {
            return NO;
        }
        return [otherLeaf.value isEqual:self.value] &&
               [otherLeaf.priorityNode isEqual:self.priorityNode];
    } else {
        return NO;
    }
}

- (NSUInteger)hash {
    return [self.value hash] * 17 + self.priorityNode.hash;
}

- (id<FNode>)withIndex:(id<FIndex>)index {
    return self;
}

- (BOOL)isIndexed:(id<FIndex>)index {
    return YES;
}

- (BOOL)isEmpty {
    return NO;
}

- (int)numChildren {
    return 0;
}

- (void)enumerateChildrenUsingBlock:(void (^)(NSString *, id<FNode>,
                                              BOOL *))block {
    // Nothing to iterate over
}

- (void)enumerateChildrenReverse:(BOOL)reverse
                      usingBlock:
                          (void (^)(NSString *, id<FNode>, BOOL *))block {
    // Nothing to iterate over
}

- (NSEnumerator *)childEnumerator {
    // Nothing to iterate over
    return [@[] objectEnumerator];
}

- (NSString *)dataHash {
    if (self.lazyHash == nil) {
        NSMutableString *toHash = [[NSMutableString alloc] init];
        [FSnapshotUtilities
            appendHashRepresentationForLeafNode:self
                                       toString:toHash
                                    hashVersion:FDataHashVersionV1];

        self.lazyHash = [FStringUtilities base64EncodedSha1:toHash];
    }
    return self.lazyHash;
}

- (NSComparisonResult)compare:(id<FNode>)other {
    if (other == [FEmptyNode emptyNode]) {
        return NSOrderedDescending;
    } else if ([other isKindOfClass:[FChildrenNode class]]) {
        return NSOrderedAscending;
    } else {
        NSAssert(other.isLeafNode, @"Compared against unknown type of node.");
        return [self compareToLeafNode:(FLeafNode *)other];
    }
}

+ (NSArray *)valueTypeOrder {
    static NSArray *valueOrder = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
      valueOrder = @[
          kJavaScriptObject, kJavaScriptBoolean, kJavaScriptNumber,
          kJavaScriptString
      ];
    });
    return valueOrder;
}

- (NSComparisonResult)compareToLeafNode:(FLeafNode *)other {
    NSString *thisLeafType = [FUtilities getJavascriptType:self.value];
    NSString *otherLeafType = [FUtilities getJavascriptType:other.value];
    NSUInteger thisIndex =
        [[FLeafNode valueTypeOrder] indexOfObject:thisLeafType];
    NSUInteger otherIndex =
        [[FLeafNode valueTypeOrder] indexOfObject:otherLeafType];
    assert(thisIndex >= 0 && otherIndex >= 0);
    if (otherIndex == thisIndex) {
        // Same type.  Compare values.
        if (thisLeafType == kJavaScriptObject) {
            // Deferred value nodes are all equal, but we should also never get
            // to this point...
            return NSOrderedSame;
        } else if (thisLeafType == kJavaScriptString) {
            return [self.value compare:other.value options:NSLiteralSearch];
        } else {
            return [self.value compare:other.value];
        }
    } else {
        return thisIndex > otherIndex ? NSOrderedDescending
                                      : NSOrderedAscending;
    }
}

- (NSString *)description {
    return [[self valForExport:YES] description];
}

- (void)forEachChildDo:(fbt_bool_nsstring_node)action {
    // There are no children, so there is nothing to do.
    return;
}

@end
