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

#import "FServerValues.h"
#import "FChildrenNode.h"
#import "FConstants.h"
#import "FLeafNode.h"
#import "FSnapshotUtilities.h"

const NSString *kTimestamp = @"timestamp";
const NSString *kIncrement = @"increment";

BOOL canBeRepresentedAsLong(NSNumber *num) {
    switch (num.objCType[0]) {
    case 'f': // float; fallthrough
    case 'd': // double
        return NO;
    case 'L': // unsigned long; fallthrough
    case 'Q': // unsigned long long; fallthrough
        // Only use ulong(long) if there isn't an overflow.
        if (num.unsignedLongLongValue > LONG_MAX) {
            return NO;
        }
    }
    return YES;
}

@interface FServerValues ()
+ (id)resolveScalarServerOp:(NSString *)op
           withServerValues:(NSDictionary *)serverValues;
+ (id)resolveComplexServerOp:(NSDictionary *)op
                withExisting:(id<FNode>)existing
                serverValues:(NSDictionary *)serverValues;
@end

@implementation FServerValues

+ (NSDictionary *)generateServerValues:(id<FClock>)clock {
    long long millis = (long long)([clock currentTime] * 1000);
    return @{kTimestamp : [NSNumber numberWithLongLong:millis]};
}

+ (id)resolveDeferredValue:(id)val
              withExisting:(id<FNode>)existing
              serverValues:(NSDictionary *)serverValues {
    if (![val isKindOfClass:[NSDictionary class]]) {
        return val;
    }
    NSDictionary *dict = val;
    id op = dict[kServerValueSubKey];

    if (op == nil) {
        return val;
    } else if ([op isKindOfClass:NSString.class]) {
        return [FServerValues resolveScalarServerOp:op
                                   withServerValues:serverValues];
    } else if ([op isKindOfClass:NSDictionary.class]) {
        return [FServerValues resolveComplexServerOp:op
                                        withExisting:existing
                                        serverValues:serverValues];
    }
    return val;
}

+ (id)resolveScalarServerOp:(NSString *)op
           withServerValues:(NSDictionary *)serverValues {
    return serverValues[op];
}

+ (id)resolveComplexServerOp:(NSDictionary *)op
                withExisting:(id<FNode>)existing
                serverValues:(NSDictionary *)serverValues {
    // Only increment is supported as of now
    if (op[kIncrement] == nil) {
        return nil;
    }

    // Incrementing a non-number sets the value to the incremented amount
    NSNumber *delta = op[kIncrement];
    if (![existing isLeafNode]) {
        return delta;
    }
    FLeafNode *existingLeaf = existing;
    if (![existingLeaf.value isKindOfClass:NSNumber.class]) {
        return delta;
    }

    NSNumber *existingNum = existingLeaf.value;
    BOOL incrLong = canBeRepresentedAsLong(delta);
    BOOL baseLong = canBeRepresentedAsLong(existingNum);

    if (incrLong && baseLong) {
        long x = delta.longValue;
        long y = existingNum.longValue;
        long r = x + y;

        // See "Hacker's Delight" 2-12: Overflow if both arguments have the
        // opposite sign of the result
        if (((x ^ r) & (y ^ r)) >= 0) {
            return @(r);
        }
    }
    return @(delta.doubleValue + existingNum.doubleValue);
}

+ (FCompoundWrite *)resolveDeferredValueCompoundWrite:(FCompoundWrite *)write
                                         withExisting:(id<FNode>)existing
                                         serverValues:
                                             (NSDictionary *)serverValues {
    __block FCompoundWrite *resolved = write;
    [write enumerateWrites:^(FPath *path, id<FNode> node, BOOL *stop) {
      id<FNode> resolvedNode =
          [FServerValues resolveDeferredValueSnapshot:node
                                         withExisting:existing
                                         serverValues:serverValues];
      // Node actually changed, use pointer inequality here
      if (resolvedNode != node) {
          resolved = [resolved addWrite:resolvedNode atPath:path];
      }
    }];
    return resolved;
}

+ (id)resolveDeferredValueTree:(FSparseSnapshotTree *)tree
                  withExisting:(id<FNode>)existing
                  serverValues:(NSDictionary *)serverValues {
    FSparseSnapshotTree *resolvedTree = [[FSparseSnapshotTree alloc] init];
    [tree
        forEachTreeAtPath:[FPath empty]
                       do:^(FPath *path, id<FNode> node) {
                         [resolvedTree
                             rememberData:
                                 [FServerValues
                                     resolveDeferredValueSnapshot:node
                                                     withExisting:
                                                         [existing
                                                             getChild:path]
                                                     serverValues:serverValues]
                                   onPath:path];
                       }];
    return resolvedTree;
}

+ (id<FNode>)resolveDeferredValueSnapshot:(id<FNode>)node
                             withExisting:(id<FNode>)existing
                             serverValues:(NSDictionary *)serverValues {
    id priorityVal =
        [FServerValues resolveDeferredValue:[[node getPriority] val]
                               withExisting:existing.getPriority
                               serverValues:serverValues];
    id<FNode> priority = [FSnapshotUtilities nodeFrom:priorityVal];

    if ([node isLeafNode]) {
        id value = [self resolveDeferredValue:[node val]
                                 withExisting:existing
                                 serverValues:serverValues];
        if (![value isEqual:[node val]] ||
            ![priority isEqual:[node getPriority]]) {
            return [[FLeafNode alloc] initWithValue:value
                                       withPriority:priority];
        } else {
            return node;
        }
    } else {
        __block FChildrenNode *newNode = node;
        if (![priority isEqual:[node getPriority]]) {
            newNode = [newNode updatePriority:priority];
        }

        [node enumerateChildrenUsingBlock:^(NSString *childKey,
                                            id<FNode> childNode, BOOL *stop) {
          id newChildNode = [FServerValues
              resolveDeferredValueSnapshot:childNode
                              withExisting:[existing getImmediateChild:childKey]
                              serverValues:serverValues];
          if (![newChildNode isEqual:childNode]) {
              newNode = [newNode updateImmediateChild:childKey
                                         withNewChild:newChildNode];
          }
        }];
        return newNode;
    }
}

@end
