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

#import "FCompoundHash.h"
#import "FLeafNode.h"
#import "FStringUtilities.h"
#import "FSnapshotUtilities.h"
#import "FChildrenNode.h"

@interface FCompoundHashBuilder ()

@property (nonatomic, strong) FCompoundHashSplitStrategy splitStrategy;

@property (nonatomic, strong) NSMutableArray *currentPaths;
@property (nonatomic, strong) NSMutableArray *currentHashes;

@end

@implementation FCompoundHashBuilder {

    // NOTE: We use the existence of this to know if we've started building a range (i.e. encountered a leaf node).
    NSMutableString *optHashValueBuilder;

    // The current path as a stack. This is used in combination with currentPathDepth to simultaneously store the
    // last leaf node path. The depth is changed when descending and ascending, at the same time the current key
    // is set for the current depth. Because the keys are left unchanged for ascending the path will also contain
    // the path of the last visited leaf node (using lastLeafDepth elements)
    NSMutableArray *currentPath;
    NSInteger lastLeafDepth;
    NSInteger currentPathDepth;

    BOOL needsComma;
}

- (instancetype)initWithSplitStrategy:(FCompoundHashSplitStrategy)strategy {
    self = [super init];
    if (self != nil) {
        self->_splitStrategy = strategy;
        self->optHashValueBuilder = nil;
        self->currentPath = [NSMutableArray array];
        self->lastLeafDepth = -1;
        self->currentPathDepth = 0;
        self->needsComma = YES;
        self->_currentPaths = [NSMutableArray array];
        self->_currentHashes = [NSMutableArray array];
    }
    return self;
}

- (BOOL)isBuildingRange {
    return self->optHashValueBuilder != nil;
}

- (NSUInteger)currentHashLength {
    return self->optHashValueBuilder.length;
}

- (FPath *)currentPath {
    return [self currentPathWithDepth:self->currentPathDepth];
}

- (FPath *)currentPathWithDepth:(NSInteger)depth {
    NSArray *pieces = [self->currentPath subarrayWithRange:NSMakeRange(0, depth)];
    return [[FPath alloc] initWithPieces:pieces andPieceNum:0];
}

- (void)enumerateCurrentPathToDepth:(NSInteger)depth withBlock:(void (^) (NSString *key))block {
    for (NSInteger i = 0; i < depth; i++) {
        block(self->currentPath[i]);
    }
}

- (void)appendKey:(NSString *)key toString:(NSMutableString *)string {
    [FSnapshotUtilities appendHashV2RepresentationForString:key toString:string];
}

- (void)ensureRange {
    if (![self isBuildingRange]) {
        optHashValueBuilder = [NSMutableString string];
        [optHashValueBuilder appendString:@"("];
        [self enumerateCurrentPathToDepth:self->currentPathDepth withBlock:^(NSString *key) {
            [self appendKey:key toString:self->optHashValueBuilder];
            [self->optHashValueBuilder appendString:@":("];
        }];
        self->needsComma = NO;
    }
}

- (void)processLeaf:(FLeafNode *)leafNode {
    [self ensureRange];

    self->lastLeafDepth = self->currentPathDepth;
    [FSnapshotUtilities appendHashRepresentationForLeafNode:leafNode
                                                   toString:self->optHashValueBuilder
                                                hashVersion:FDataHashVersionV2];
    self->needsComma = YES;
    if (self.splitStrategy(self)) {
        [self endRange];
    }
}

- (void)startChild:(NSString *)key {
    [self ensureRange];

    if (self->needsComma) {
        [self->optHashValueBuilder appendString:@","];
    }
    [self appendKey:key toString:self->optHashValueBuilder];
    [self->optHashValueBuilder appendString:@":("];
    if (self->currentPathDepth == currentPath.count) {
        [self->currentPath addObject:key];
    } else {
        self->currentPath[self->currentPathDepth] = key;
    }
    self->currentPathDepth++;
    self->needsComma = NO;
}

- (void)endChild {
    self->currentPathDepth--;
    if ([self isBuildingRange]) {
        [self->optHashValueBuilder appendString:@")"];
    }
    self->needsComma = YES;
}

- (void)finishHashing {
    NSAssert(self->currentPathDepth == 0, @"Can't finish hashing in the middle of processing a child");
    if ([self isBuildingRange] ) {
        [self endRange];
    }

    // Always close with the empty hash for the remaining range to allow simple appending
    [self.currentHashes addObject:@""];
}

- (void)endRange {
    NSAssert([self isBuildingRange], @"Can't end range without starting a range!");
    // Add closing parenthesis for current depth
    for (NSUInteger i = 0; i < currentPathDepth; i++) {
        [self->optHashValueBuilder appendString:@")"];
    }
    [self->optHashValueBuilder appendString:@")"];

    FPath *lastLeafPath = [self currentPathWithDepth:self->lastLeafDepth];
    NSString *hash = [FStringUtilities base64EncodedSha1:self->optHashValueBuilder];
    [self.currentHashes addObject:hash];
    [self.currentPaths addObject:lastLeafPath];

    self->optHashValueBuilder = nil;
}

@end


@interface FCompoundHash ()

@property (nonatomic, strong, readwrite) NSArray *posts;
@property (nonatomic, strong, readwrite) NSArray *hashes;

@end

@implementation FCompoundHash

- (id)initWithPosts:(NSArray *)posts hashes:(NSArray *)hashes {
    self = [super init];
    if (self != nil) {
        if (posts.count != hashes.count - 1) {
            [NSException raise:NSInvalidArgumentException format:@"Number of posts need to be n-1 for n hashes in FCompoundHash"];
        }
        self.posts = posts;
        self.hashes = hashes;
    }
    return self;
}

+ (FCompoundHashSplitStrategy)simpleSizeSplitStrategyForNode:(id<FNode>)node {
    NSUInteger estimatedSize = [FSnapshotUtilities estimateSerializedNodeSize:node];

    // Splits for
    // 1k -> 512 (2 parts)
    // 5k -> 715 (7 parts)
    // 100k -> 3.2k (32 parts)
    // 500k -> 7k (71 parts)
    // 5M -> 23k (228 parts)
    NSUInteger splitThreshold = MAX(512, (NSUInteger)sqrt(estimatedSize * 100));

    return ^BOOL(FCompoundHashBuilder *builder) {
        // Never split on priorities
        return [builder currentHashLength] > splitThreshold && ![[[builder currentPath] getBack] isEqualToString:@".priority"];
    };
}

+ (FCompoundHash *)fromNode:(id<FNode>)node {
    return [FCompoundHash fromNode:node splitStrategy:[FCompoundHash simpleSizeSplitStrategyForNode:node]];
}

+ (FCompoundHash *)fromNode:(id<FNode>)node splitStrategy:(FCompoundHashSplitStrategy)strategy {
    if ([node isEmpty]) {
        return [[FCompoundHash alloc] initWithPosts:@[] hashes:@[@""]];
    } else {
        FCompoundHashBuilder *builder = [[FCompoundHashBuilder alloc] initWithSplitStrategy:strategy];
        [FCompoundHash processNode:node builder:builder];
        [builder finishHashing];
        return [[FCompoundHash alloc] initWithPosts:builder.currentPaths hashes:builder.currentHashes];
    }
}

+ (void)processNode:(id<FNode>)node builder:(FCompoundHashBuilder *)builder {
    if ([node isLeafNode]) {
        [builder processLeaf:node];
    } else {
        NSAssert(![node isEmpty], @"Can't calculate hash on empty node!");
        FChildrenNode *childrenNode = (FChildrenNode *)node;
        [childrenNode enumerateChildrenAndPriorityUsingBlock:^(NSString *key, id<FNode> node, BOOL *stop) {
            [builder startChild:key];
            [self processNode:node builder:builder];
            [builder endChild];
        }];
    }
}

@end
