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
#import "FConstants.h"
#import "FLeafNode.h"
#import "FChildrenNode.h"
#import "FSnapshotUtilities.h"

@implementation FServerValues

+ (NSDictionary*) generateServerValues:(id<FClock>)clock {
    long long millis = (long long)([clock currentTime] * 1000);
    return @{ @"timestamp": [NSNumber numberWithLongLong:millis] };
}

+ (id) resolveDeferredValue:(id)val withServerValues:(NSDictionary*)serverValues {
    if ([val isKindOfClass:[NSDictionary class]]) {
        NSDictionary* dict = val;
        if (dict[kServerValueSubKey] != nil) {
            NSString* serverValueType = [dict objectForKey:kServerValueSubKey];
            if (serverValues[serverValueType] != nil) {
                return [serverValues objectForKey:serverValueType];
            } else {
                // TODO: Throw unrecognizedServerValue error here
            }
        }
    }
    return val;
}

+ (FCompoundWrite *) resolveDeferredValueCompoundWrite:(FCompoundWrite *)write withServerValues:(NSDictionary *)serverValues {
    __block FCompoundWrite *resolved = write;
    [write enumerateWrites:^(FPath *path, id<FNode> node, BOOL *stop) {
        id<FNode> resolvedNode = [FServerValues resolveDeferredValueSnapshot:node withServerValues:serverValues];
        // Node actually changed, use pointer inequality here
        if (resolvedNode != node) {
            resolved = [resolved addWrite:resolvedNode atPath:path];
        }
    }];
    return resolved;
}

+ (id) resolveDeferredValueTree:(FSparseSnapshotTree*)tree withServerValues:(NSDictionary*)serverValues {
    FSparseSnapshotTree* resolvedTree = [[FSparseSnapshotTree alloc] init];
    [tree forEachTreeAtPath:[FPath empty] do:^(FPath* path, id<FNode> node) {
        [resolvedTree rememberData:[FServerValues resolveDeferredValueSnapshot:node withServerValues:serverValues] onPath:path];
    }];
    return resolvedTree;
}

+ (id<FNode>) resolveDeferredValueSnapshot:(id<FNode>)node withServerValues:(NSDictionary*)serverValues {
    id priorityVal = [FServerValues resolveDeferredValue:[[node getPriority] val] withServerValues:serverValues];
    id<FNode> priority = [FSnapshotUtilities nodeFrom:priorityVal];

    if ([node isLeafNode]) {
        id value = [self resolveDeferredValue:[node val] withServerValues:serverValues];
        if (![value isEqual:[node val]] || ![priority isEqual:[node getPriority]]) {
            return [[FLeafNode alloc] initWithValue:value withPriority:priority];
        } else {
            return node;
        }
    } else {
        __block FChildrenNode* newNode = node;
        if (![priority isEqual:[node getPriority]]) {
          newNode = [newNode updatePriority:priority];
        }

        [node enumerateChildrenUsingBlock:^(NSString *childKey, id<FNode> childNode, BOOL *stop) {
            id newChildNode = [FServerValues resolveDeferredValueSnapshot:childNode withServerValues:serverValues];
            if (![newChildNode isEqual:childNode]) {
                newNode = [newNode updateImmediateChild:childKey withNewChild:newChildNode];
            }
        }];
        return newNode;
    }
}

@end

