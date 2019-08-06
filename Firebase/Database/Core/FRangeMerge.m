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

#import "FRangeMerge.h"

#import "FEmptyNode.h"

@interface FRangeMerge ()

@property(nonatomic, strong) FPath *optExclusiveStart;
@property(nonatomic, strong) FPath *optInclusiveEnd;
@property(nonatomic, strong) id<FNode> updates;

@end

@implementation FRangeMerge

- (instancetype)initWithStart:(FPath *)start
                          end:(FPath *)end
                      updates:(id<FNode>)updates {
    self = [super init];
    if (self != nil) {
        self->_optExclusiveStart = start;
        self->_optInclusiveEnd = end;
        self->_updates = updates;
    }
    return self;
}

- (id<FNode>)applyToNode:(id<FNode>)node {
    return [self updateRangeInNode:[FPath empty]
                              node:node
                           updates:self.updates];
}

- (id<FNode>)updateRangeInNode:(FPath *)currentPath
                          node:(id<FNode>)node
                       updates:(id<FNode>)updates {
    NSComparisonResult startComparison =
        (self.optExclusiveStart == nil)
            ? NSOrderedDescending
            : [currentPath compare:self.optExclusiveStart];
    NSComparisonResult endComparison =
        (self.optInclusiveEnd == nil)
            ? NSOrderedAscending
            : [currentPath compare:self.optInclusiveEnd];
    BOOL startInNode = self.optExclusiveStart != nil &&
                       [currentPath contains:self.optExclusiveStart];
    BOOL endInNode = self.optInclusiveEnd != nil &&
                     [currentPath contains:self.optInclusiveEnd];
    if (startComparison == NSOrderedDescending &&
        endComparison == NSOrderedAscending && !endInNode) {
        // child is completly contained
        return updates;
    } else if (startComparison == NSOrderedDescending && endInNode &&
               [updates isLeafNode]) {
        return updates;
    } else if (startComparison == NSOrderedDescending &&
               endComparison == NSOrderedSame) {
        NSAssert(endInNode, @"End not in node");
        NSAssert(![updates isLeafNode], @"Found leaf node update, this case "
                                        @"should have been handled above.");
        if ([node isLeafNode]) {
            // Update node was not a leaf node, so we can delete it
            return [FEmptyNode emptyNode];
        } else {
            // Unaffected by range, ignore
            return node;
        }
    } else if (startInNode || endInNode) {
        // There is a partial update we need to do, so collect all relevant
        // children
        NSMutableSet *allChildren = [NSMutableSet set];
        [node enumerateChildrenUsingBlock:^(NSString *key, id<FNode> node,
                                            BOOL *stop) {
          [allChildren addObject:key];
        }];
        [updates enumerateChildrenUsingBlock:^(NSString *key, id<FNode> node,
                                               BOOL *stop) {
          [allChildren addObject:key];
        }];

        __block id<FNode> newNode = node;
        void (^action)(id, BOOL *) = ^void(NSString *key, BOOL *stop) {
          id<FNode> currentChild = [node getImmediateChild:key];
          id<FNode> updatedChild =
              [self updateRangeInNode:[currentPath childFromString:key]
                                 node:currentChild
                              updates:[updates getImmediateChild:key]];
          // Only need to update if the node changed
          if (updatedChild != currentChild) {
              newNode = [newNode updateImmediateChild:key
                                         withNewChild:updatedChild];
          }
        };

        [allChildren enumerateObjectsUsingBlock:action];

        // Add priority last, so the node is not empty when applying
        if (!updates.getPriority.isEmpty || !node.getPriority.isEmpty) {
            BOOL stop = NO;
            action(@".priority", &stop);
        }
        return newNode;
    } else {
        // Unaffected by this range
        NSAssert(endComparison == NSOrderedDescending ||
                     startComparison <= NSOrderedSame,
                 @"Invalid range for update");
        return node;
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"RangeMerge (optExclusiveStart = %@, "
                                      @"optExclusiveEng = %@, updates = %@)",
                                      self.optExclusiveStart,
                                      self.optInclusiveEnd, self.updates];
}

@end
