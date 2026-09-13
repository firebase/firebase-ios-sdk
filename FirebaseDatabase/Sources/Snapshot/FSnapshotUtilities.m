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

#import "FSnapshotUtilities.h"
#import "FChildrenNode.h"
#import "FCompoundWrite.h"
#import "FConstants.h"
#import "FEmptyNode.h"
#import "FLLRBValueNode.h"
#import "FLeafNode.h"
#import "FMaxNode.h"
#import "FNamedNode.h"
#import "FUtilities.h"
#import "FValidation.h"

@implementation FSnapshotUtilities

+ (id<FNode>)nodeFrom:(id)val {
    return [FSnapshotUtilities nodeFrom:val priority:nil];
}

+ (id<FNode>)nodeFrom:(id)val priority:(id)priority {
    return [FSnapshotUtilities nodeFrom:val
                               priority:priority
                     withValidationFrom:@"nodeFrom:priority:"];
}

+ (id<FNode>)nodeFrom:(id)val withValidationFrom:(NSString *)fn {
    return [FSnapshotUtilities nodeFrom:val priority:nil withValidationFrom:fn];
}

+ (id<FNode>)nodeFrom:(id)val
              priority:(id)priority
    withValidationFrom:(NSString *)fn {
    return [FSnapshotUtilities nodeFrom:val
                               priority:priority
                     withValidationFrom:fn
                                atDepth:0
                                   path:[[NSMutableArray alloc] init]];
}

+ (id<FNode>)nodeFrom:(id)val
              priority:(id)aPriority
    withValidationFrom:(NSString *)fn
               atDepth:(int)depth
                  path:(NSMutableArray *)path {
    @autoreleasepool {
        return [FSnapshotUtilities internalNodeFrom:val
                                           priority:aPriority
                                 withValidationFrom:fn
                                            atDepth:depth
                                               path:path];
    }
}

+ (id<FNode>)internalNodeFrom:(id)val
                     priority:(id)aPriority
           withValidationFrom:(NSString *)fn
                      atDepth:(int)depth
                         path:(NSMutableArray *)path {

    if (depth > kFirebaseMaxObjectDepth) {
        NSRange range;
        range.location = 0;
        range.length = 100;
        NSString *pathString =
            [[path subarrayWithRange:range] componentsJoinedByString:@"."];
        @throw [[NSException alloc]
            initWithName:@"InvalidFirebaseData"
                  reason:[NSString stringWithFormat:
                                       @"(%@) Max object depth exceeded: %@...",
                                       fn, pathString]
                userInfo:nil];
    }

    if (val == nil || val == [NSNull null]) {
        // Null is a valid type to store
        return [FEmptyNode emptyNode];
    }

    [FValidation validateFrom:fn isValidPriorityValue:aPriority withPath:path];
    id<FNode> priority = [FSnapshotUtilities nodeFrom:aPriority];

    id value = val;
    BOOL isLeafNode = NO;

    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = val;
        if (dict[kPayloadPriority] != nil) {
            id rawPriority = [dict objectForKey:kPayloadPriority];
            [FValidation validateFrom:fn
                 isValidPriorityValue:rawPriority
                             withPath:path];
            priority = [FSnapshotUtilities nodeFrom:rawPriority];
        }

        if (dict[kPayloadValue] != nil) {
            value = [dict objectForKey:kPayloadValue];
            if ([FValidation validateFrom:fn
                         isValidLeafValue:value
                                 withPath:path]) {
                isLeafNode = YES;
            } else {
                @throw [[NSException alloc]
                    initWithName:@"InvalidLeafValueType"
                          reason:[NSString stringWithFormat:
                                               @"(%@) Invalid data type used "
                                               @"with .value. Can only use "
                                                "NSString and NSNumber or be "
                                                "null. Found %@ instead.",
                                               fn, [[value class] description]]
                        userInfo:nil];
            }
        }
    }

    if ([FValidation validateFrom:fn isValidLeafValue:value withPath:path]) {
        isLeafNode = YES;
    }

    if (isLeafNode) {
        return [[FLeafNode alloc] initWithValue:value withPriority:priority];
    }

    // Unlike with JS, we have to handle the dictionary and array cases
    // separately.
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dval = (NSDictionary *)value;
        NSMutableDictionary *children =
            [NSMutableDictionary dictionaryWithCapacity:dval.count];

        // Avoid creating a million newPaths by appending to old one
        for (id keyId in dval) {
            [FValidation validateFrom:fn
                   validDictionaryKey:keyId
                             withPath:path];
            NSString *key = (NSString *)keyId;

            if (![key hasPrefix:kPayloadMetadataPrefix]) {
                [path addObject:key];
                id<FNode> childNode = [FSnapshotUtilities nodeFrom:dval[key]
                                                          priority:nil
                                                withValidationFrom:fn
                                                           atDepth:depth + 1
                                                              path:path];
                [path removeLastObject];

                if (![childNode isEmpty]) {
                    children[key] = childNode;
                }
            }
        }

        if ([children count] == 0) {
            return [FEmptyNode emptyNode];
        } else {
            FImmutableSortedDictionary *childrenDict =
                [FImmutableSortedDictionary
                    fromDictionary:children
                    withComparator:[FUtilities keyComparator]];
            return [[FChildrenNode alloc] initWithPriority:priority
                                                  children:childrenDict];
        }
    } else if ([value isKindOfClass:[NSArray class]]) {
        NSArray *aval = (NSArray *)value;
        NSMutableDictionary *children =
            [NSMutableDictionary dictionaryWithCapacity:aval.count];

        for (int i = 0; i < [aval count]; i++) {
            NSString *key = [NSString stringWithFormat:@"%i", i];
            [path addObject:key];
            id<FNode> childNode =
                [FSnapshotUtilities nodeFrom:[aval objectAtIndex:i]
                                    priority:nil
                          withValidationFrom:fn
                                     atDepth:depth + 1
                                        path:path];
            [path removeLastObject];

            if (![childNode isEmpty]) {
                children[key] = childNode;
            }
        }

        if ([children count] == 0) {
            return [FEmptyNode emptyNode];
        } else {
            FImmutableSortedDictionary *childrenDict =
                [FImmutableSortedDictionary
                    fromDictionary:children
                    withComparator:[FUtilities keyComparator]];
            return [[FChildrenNode alloc] initWithPriority:priority
                                                  children:childrenDict];
        }
    } else {
        NSRange range;
        range.location = 0;
        range.length = MIN(path.count, 50);
        NSString *pathString =
            [[path subarrayWithRange:range] componentsJoinedByString:@"."];

        @throw [[NSException alloc]
            initWithName:@"InvalidFirebaseData"
                  reason:[NSString
                             stringWithFormat:
                                 @"(%@) Cannot store object of type %@ at %@. "
                                  "Can only store objects of type NSNumber, "
                                  "NSString, NSDictionary, and NSArray.",
                                 fn, [[value class] description], pathString]
                userInfo:nil];
    }
}

+ (FCompoundWrite *)compoundWriteFromDictionary:(NSDictionary *)values
                             withValidationFrom:(NSString *)fn {
    FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];

    NSMutableArray *updatePaths =
        [NSMutableArray arrayWithCapacity:values.count];
    for (NSString *keyId in values) {
        id value = values[keyId];
        [FValidation validateFrom:fn
            validUpdateDictionaryKey:keyId
                           withValue:value];

        FPath *path = [FPath pathWithString:keyId];
        id<FNode> node = [FSnapshotUtilities nodeFrom:value
                                   withValidationFrom:fn];

        [updatePaths addObject:path];
        compoundWrite = [compoundWrite addWrite:node atPath:path];
    }

    // Check that the update paths are not descendants of each other.
    [updatePaths
        sortUsingComparator:^NSComparisonResult(FPath *left, FPath *right) {
          return [left compare:right];
        }];
    FPath *prevPath = nil;
    for (FPath *path in updatePaths) {
        if (prevPath != nil && [prevPath contains:path]) {
            @throw [[NSException alloc]
                initWithName:@"InvalidFirebaseData"
                      reason:[NSString stringWithFormat:
                                           @"(%@) Invalid path in object. Path "
                                           @"(%@) is an ancestor of (%@).",
                                           fn, prevPath, path]
                    userInfo:nil];
        }
        prevPath = path;
    }

    return compoundWrite;
}

+ (void)validatePriorityNode:(id<FNode>)priorityNode {
    assert(priorityNode != nil);
    if (priorityNode.isLeafNode) {
        id val = priorityNode.val;
        if ([val isKindOfClass:[NSDictionary class]]) {
            NSDictionary *valDict __unused = (NSDictionary *)val;
            NSAssert(valDict[kServerValueSubKey] != nil,
                     @"Priority can't be object unless it's a deferred value");
        } else {
            NSString *jsType __unused = [FUtilities getJavascriptType:val];
            NSAssert(jsType == kJavaScriptString || jsType == kJavaScriptNumber,
                     @"Priority of unexpected type.");
        }
    } else {
        NSAssert(priorityNode == [FMaxNode maxNode] || priorityNode.isEmpty,
                 @"Priority of unexpected type.");
    }
    // Don't call getPriority() on MAX_NODE to avoid hitting assertion.
    NSAssert(priorityNode == [FMaxNode maxNode] ||
                 priorityNode.getPriority.isEmpty,
             @"Priority nodes can't have a priority of their own.");
}

+ (void)appendHashRepresentationForLeafNode:(FLeafNode *)leafNode
                                   toString:(NSMutableString *)string
                                hashVersion:(FDataHashVersion)hashVersion {
    NSAssert(hashVersion == FDataHashVersionV1 ||
                 hashVersion == FDataHashVersionV2,
             @"Unknown hash version: %lu", (unsigned long)hashVersion);
    if (!leafNode.getPriority.isEmpty) {
        [string appendString:@"priority:"];
        [FSnapshotUtilities
            appendHashRepresentationForLeafNode:leafNode.getPriority
                                       toString:string
                                    hashVersion:hashVersion];
        [string appendString:@":"];
    }

    NSString *jsType = [FUtilities getJavascriptType:leafNode.val];
    [string appendString:jsType];
    [string appendString:@":"];

    if (jsType == kJavaScriptBoolean) {
        NSString *boolString =
            [leafNode.val boolValue] ? kJavaScriptTrue : kJavaScriptFalse;
        [string appendString:boolString];
    } else if (jsType == kJavaScriptNumber) {
        NSString *numberString =
            [FUtilities ieee754StringForNumber:leafNode.val];
        [string appendString:numberString];
    } else if (jsType == kJavaScriptString) {
        if (hashVersion == FDataHashVersionV1) {
            [string appendString:leafNode.val];
        } else {
            NSAssert(hashVersion == FDataHashVersionV2,
                     @"Invalid hash version found");
            [FSnapshotUtilities appendHashV2RepresentationForString:leafNode.val
                                                           toString:string];
        }
    } else {
        [NSException raise:NSInvalidArgumentException
                    format:@"Unknown value for hashing: %@", leafNode];
    }
}

+ (void)appendHashV2RepresentationForString:(NSString *)string
                                   toString:(NSMutableString *)mutableString {
    string = [string stringByReplacingOccurrencesOfString:@"\\"
                                               withString:@"\\\\"];
    string = [string stringByReplacingOccurrencesOfString:@"\""
                                               withString:@"\\\""];
    [mutableString appendString:@"\""];
    [mutableString appendString:string];
    [mutableString appendString:@"\""];
}

+ (NSUInteger)estimateLeafNodeSize:(FLeafNode *)leafNode {
    NSString *jsType = [FUtilities getJavascriptType:leafNode.val];
    // These values are somewhat arbitrary, but we don't need an exact value so
    // prefer performance over exact value
    NSUInteger valueSize;
    if (jsType == kJavaScriptNumber) {
        valueSize = 8; // estimate each float with 8 bytes
    } else if (jsType == kJavaScriptBoolean) {
        valueSize = 4; // true or false need roughly 4 bytes
    } else if (jsType == kJavaScriptString) {
        valueSize = 2 + [leafNode.val length]; // add 2 for quotes
    } else {
        [NSException raise:NSInvalidArgumentException
                    format:@"Unknown leaf type: %@", leafNode];
        return 0;
    }

    if (leafNode.getPriority.isEmpty) {
        return valueSize;
    } else {
        // Account for extra overhead due to the extra JSON object and the
        // ".value" and ".priority" keys, colons, comma
        NSUInteger leafPriorityOverhead = 2 + 8 + 11 + 2 + 1;
        return leafPriorityOverhead + valueSize +
               [FSnapshotUtilities estimateLeafNodeSize:leafNode.getPriority];
    }
}

+ (NSUInteger)estimateSerializedNodeSize:(id<FNode>)node {
    if ([node isEmpty]) {
        return 4; // null keyword
    } else if ([node isLeafNode]) {
        return [FSnapshotUtilities estimateLeafNodeSize:node];
    } else {
        NSAssert([node isKindOfClass:[FChildrenNode class]],
                 @"Unexpected node type: %@", [node class]);
        __block NSUInteger sum = 1; // opening brackets
        [((FChildrenNode *)node) enumerateChildrenAndPriorityUsingBlock:^(
                                     NSString *key, id<FNode> child,
                                     BOOL *stop) {
          sum += key.length;
          sum +=
              4; // quotes around key and colon and (comma or closing bracket)
          sum += [FSnapshotUtilities estimateSerializedNodeSize:child];
        }];
        return sum;
    }
}

@end
