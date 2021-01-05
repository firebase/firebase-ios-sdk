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

#import "FirebaseDatabase/Sources/Core/FServerValues.h"
#import "FirebaseDatabase/Sources/Constants/FConstants.h"
#import "FirebaseDatabase/Sources/Snapshot/FChildrenNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FLeafNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FSnapshotUtilities.h"

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

// Running through CompoundWrites for all update paths has been shown to
// be a 20% pessimization in microbenchmarks. This is because it slows
// down by O(N) of the write queue length. To eliminate the performance
// hit, we wrap around existing data of either snapshot or CompoundWrite
// (allowing us to share code) and read from the CompoundWrite only when/where
// we need to calculate an incremented value's prior state.
@protocol ValueProvider <NSObject>
- (id<ValueProvider>)getChild:(NSString *)pathSegment;
- (id<FNode>)value;
@end

@interface DeferredValueProvider : NSObject <ValueProvider>
- (instancetype)initWithSyncTree:(FSyncTree *)tree atPath:(FPath *)path;
- (id<ValueProvider>)getChild:(NSString *)pathSegment;
- (id<FNode>)value;
@property FPath *path;
@property FSyncTree *tree;
@end

@interface ExistingValueProvider : NSObject <ValueProvider>
- (instancetype)initWithSnapshot:(id<FNode>)snapshot;
- (id<ValueProvider>)getChild:(NSString *)pathSegment;
- (id<FNode>)value;
@property id<FNode> snapshot;
@end

@implementation DeferredValueProvider
- (instancetype)initWithSyncTree:(FSyncTree *)tree atPath:(FPath *)path {
    self.tree = tree;
    self.path = path;
    return self;
}

- (id<ValueProvider>)getChild:(NSString *)pathSegment {
    FPath *child = [self.path childFromString:pathSegment];
    return [[DeferredValueProvider alloc] initWithSyncTree:self.tree
                                                    atPath:child];
}

- (id<FNode>)value {
    return [self.tree calcCompleteEventCacheAtPath:self.path
                                   excludeWriteIds:@[]];
}
@end

@implementation ExistingValueProvider
- (instancetype)initWithSnapshot:(id<FNode>)snapshot {
    self.snapshot = snapshot;
    return self;
}

- (id<ValueProvider>)getChild:(NSString *)pathSegment {
    return [[ExistingValueProvider alloc]
        initWithSnapshot:[self.snapshot getImmediateChild:pathSegment]];
}

- (id<FNode>)value {
    return self.snapshot;
}
@end

@interface FServerValues ()
+ (id)resolveScalarServerOp:(NSString *)op
           withServerValues:(NSDictionary *)serverValues;
+ (id)resolveComplexServerOp:(NSDictionary *)op
           withValueProvider:(id<ValueProvider>)existing
                serverValues:(NSDictionary *)serverValues;
+ (id<FNode>)resolveDeferredValueSnapshot:(id<FNode>)node
                        withValueProvider:(id<ValueProvider>)existing
                             serverValues:(NSDictionary *)serverValues;

@end

@implementation FServerValues

+ (NSDictionary *)generateServerValues:(id<FClock>)clock {
    long long millis = (long long)([clock currentTime] * 1000);
    return @{kTimestamp : [NSNumber numberWithLongLong:millis]};
}

+ (id)resolveDeferredValue:(id)val
              withExisting:(id<ValueProvider>)existing
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
                                   withValueProvider:existing
                                        serverValues:serverValues];
    }
    return val;
}

+ (id)resolveScalarServerOp:(NSString *)op
           withServerValues:(NSDictionary *)serverValues {
    return serverValues[op];
}

+ (id)resolveComplexServerOp:(NSDictionary *)op
           withValueProvider:(id<ValueProvider>)jitExisting
                serverValues:(NSDictionary *)serverValues {
    // Only increment is supported as of now
    if (op[kIncrement] == nil) {
        return nil;
    }

    // Incrementing a non-number sets the value to the incremented amount
    NSNumber *delta = op[kIncrement];
    id<FNode> existing = jitExisting.value;
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
                                         withSyncTree:(FSyncTree *)tree
                                               atPath:(FPath *)path
                                         serverValues:
                                             (NSDictionary *)serverValues {
    __block FCompoundWrite *resolved = write;
    [write enumerateWrites:^(FPath *subPath, id<FNode> node, BOOL *stop) {
      id<ValueProvider> existing =
          [[DeferredValueProvider alloc] initWithSyncTree:tree
                                                   atPath:[path child:subPath]];
      id<FNode> resolvedNode =
          [FServerValues resolveDeferredValueSnapshot:node
                                    withValueProvider:existing
                                         serverValues:serverValues];
      // Node actually changed, use pointer inequality here
      if (resolvedNode != node) {
          resolved = [resolved addWrite:resolvedNode atPath:subPath];
      }
    }];
    return resolved;
}

+ (id<FNode>)resolveDeferredValueSnapshot:(id<FNode>)node
                             withSyncTree:(FSyncTree *)tree
                                   atPath:(FPath *)path
                             serverValues:(NSDictionary *)serverValues {
    id<ValueProvider> jitExisting =
        [[DeferredValueProvider alloc] initWithSyncTree:tree atPath:path];
    return [FServerValues resolveDeferredValueSnapshot:node
                                     withValueProvider:jitExisting
                                          serverValues:serverValues];
}

+ (id<FNode>)resolveDeferredValueSnapshot:(id<FNode>)node
                             withExisting:(id<FNode>)existing
                             serverValues:(NSDictionary *)serverValues {
    id<ValueProvider> jitExisting =
        [[ExistingValueProvider alloc] initWithSnapshot:existing];
    return [FServerValues resolveDeferredValueSnapshot:node
                                     withValueProvider:jitExisting
                                          serverValues:serverValues];
}

+ (id<FNode>)resolveDeferredValueSnapshot:(id<FNode>)node
                        withValueProvider:(id<ValueProvider>)existing
                             serverValues:(NSDictionary *)serverValues {
    id priorityVal =
        [FServerValues resolveDeferredValue:[[node getPriority] val]
                               withExisting:[existing getChild:@".priority"]
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
                         withValueProvider:[existing getChild:childKey]
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
