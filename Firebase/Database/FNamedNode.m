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

#import "FNamedNode.h"
#import "FEmptyNode.h"
#import "FIndex.h"
#import "FMaxNode.h"
#import "FUtilities.h"

@interface FNamedNode ()
@property(nonatomic, strong, readwrite) NSString *name;
@property(nonatomic, strong, readwrite) id<FNode> node;
@end

@implementation FNamedNode

+ (FNamedNode *)nodeWithName:(NSString *)name node:(id<FNode>)node {
    return [[FNamedNode alloc] initWithName:name andNode:node];
}

- (id)initWithName:(NSString *)name andNode:(id<FNode>)node {
    self = [super init];
    if (self) {
        self.name = name;
        self.node = node;
    }
    return self;
}

- (id)copy {
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

+ (FNamedNode *)min {
    static FNamedNode *min = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
      min = [[FNamedNode alloc] initWithName:[FUtilities minName]
                                     andNode:[FEmptyNode emptyNode]];
    });
    return min;
}

+ (FNamedNode *)max {
    static FNamedNode *max = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
      max = [[FNamedNode alloc] initWithName:[FUtilities maxName]
                                     andNode:[FMaxNode maxNode]];
    });
    return max;
}

- (NSString *)description {
    return
        [NSString stringWithFormat:@"NamedNode[%@] %@", self.name, self.node];
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (object == nil || ![object isKindOfClass:[FNamedNode class]]) {
        return NO;
    }

    FNamedNode *namedNode = object;
    if (![self.name isEqualToString:namedNode.name]) {
        return NO;
    }
    if (![self.node isEqual:namedNode.node]) {
        return NO;
    }

    return YES;
}

- (NSUInteger)hash {
    NSUInteger nameHash = [self.name hash];
    NSUInteger nodeHash = [self.node hash];
    NSUInteger result = 31 * nameHash + nodeHash;
    return result;
}

@end
