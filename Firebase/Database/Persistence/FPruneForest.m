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

#import "FPruneForest.h"

#import "FImmutableTree.h"

@interface FPruneForest ()

@property (nonatomic, strong) FImmutableTree *pruneForest;

@end

@implementation FPruneForest

static BOOL (^kFPrunePredicate)(id) = ^BOOL(NSNumber *pruneValue) {
    return [pruneValue boolValue];
};

static BOOL (^kFKeepPredicate)(id) = ^BOOL(NSNumber *pruneValue) {
    return ![pruneValue boolValue];
};


+ (FImmutableTree *)pruneTree {
    static dispatch_once_t onceToken;
    static FImmutableTree *pruneTree;
    dispatch_once(&onceToken, ^{
        pruneTree = [[FImmutableTree alloc] initWithValue:@YES];
    });
    return pruneTree;
}

+ (FImmutableTree *)keepTree {
    static dispatch_once_t onceToken;
    static FImmutableTree *keepTree;
    dispatch_once(&onceToken, ^{
        keepTree = [[FImmutableTree alloc] initWithValue:@NO];
    });
    return keepTree;
}

- (id) initWithForest:(FImmutableTree *)tree {
    self = [super init];
    if (self != nil) {
        self->_pruneForest = tree;
    }
    return self;
}

+ (FPruneForest *)empty {
    static dispatch_once_t onceToken;
    static FPruneForest *forest;
    dispatch_once(&onceToken, ^{
        forest = [[FPruneForest alloc] initWithForest:[FImmutableTree empty]];
    });
    return forest;
}

- (BOOL)prunesAnything {
    return [self.pruneForest containsValueMatching:kFPrunePredicate];
}

- (BOOL)shouldPruneUnkeptDescendantsAtPath:(FPath *)path {
    NSNumber *shouldPrune = [self.pruneForest leafMostValueOnPath:path];
    return shouldPrune != nil && [shouldPrune boolValue];
}

- (BOOL)shouldKeepPath:(FPath *)path {
    NSNumber *shouldPrune = [self.pruneForest leafMostValueOnPath:path];
    return shouldPrune != nil && ![shouldPrune boolValue];
}

- (BOOL)affectsPath:(FPath *)path {
    return [self.pruneForest rootMostValueOnPath:path] != nil || ![[self.pruneForest subtreeAtPath:path] isEmpty];
}

- (FPruneForest *)child:(NSString *)childKey {
    FImmutableTree *childPruneForest = [self.pruneForest.children get:childKey];
    if (childPruneForest == nil) {
        if (self.pruneForest.value != nil) {
            childPruneForest = [self.pruneForest.value boolValue] ? [FPruneForest pruneTree] : [FPruneForest keepTree];
        } else {
            childPruneForest = [FImmutableTree empty];
        }
    } else {
        if (childPruneForest.value == nil && self.pruneForest.value != nil) {
            childPruneForest = [childPruneForest setValue:self.pruneForest.value atPath:[FPath empty]];
        }
    }
    return [[FPruneForest alloc] initWithForest:childPruneForest];
}

- (FPruneForest *)childAtPath:(FPath *)path {
    if (path.isEmpty) {
        return self;
    } else {
        return [[self child:path.getFront] childAtPath:[path popFront]];
    }
}

- (FPruneForest *)prunePath:(FPath *)path {
    if ([self.pruneForest rootMostValueOnPath:path matching:kFKeepPredicate]) {
        [NSException raise:NSInvalidArgumentException format:@"Can't prune path that was kept previously!"];
    }
    if ([self.pruneForest rootMostValueOnPath:path matching:kFPrunePredicate]) {
        // This path will already be pruned
        return self;
    } else {
        FImmutableTree *newPruneForest = [self.pruneForest setTree:[FPruneForest pruneTree] atPath:path];
        return [[FPruneForest alloc] initWithForest:newPruneForest];
    }
}

- (FPruneForest *)keepPath:(FPath *)path {
    if ([self.pruneForest rootMostValueOnPath:path matching:kFKeepPredicate]) {
        // This path will already be kept
        return self;
    } else {
        FImmutableTree *newPruneForest = [self.pruneForest setTree:[FPruneForest keepTree] atPath:path];
        return [[FPruneForest alloc] initWithForest:newPruneForest];
    }
}

- (FPruneForest *)keepAll:(NSSet *)children atPath:(FPath *)path {
    if ([self.pruneForest rootMostValueOnPath:path matching:kFKeepPredicate]) {
        // This path will already be kept
        return self;
    } else {
        return [self setPruneValue:[FPruneForest keepTree] forAll:children atPath:path];
    }
}

- (FPruneForest *)pruneAll:(NSSet *)children atPath:(FPath *)path {
    if ([self.pruneForest rootMostValueOnPath:path matching:kFKeepPredicate]) {
        [NSException raise:NSInvalidArgumentException format:@"Can't prune path that was kept previously!"];
    }
    if ([self.pruneForest rootMostValueOnPath:path matching:kFPrunePredicate]) {
        // This path will already be pruned
        return self;
    } else {
        return [self setPruneValue:[FPruneForest pruneTree] forAll:children atPath:path];
    }
}

- (FPruneForest *)setPruneValue:(FImmutableTree *)pruneValue forAll:(NSSet *)children atPath:(FPath *)path {
    FImmutableTree *subtree = [self.pruneForest subtreeAtPath:path];
    __block FImmutableSortedDictionary *childrenDictionary = subtree.children;
    [children enumerateObjectsUsingBlock:^(NSString *childKey, BOOL *stop) {
        childrenDictionary = [childrenDictionary insertKey:childKey withValue:pruneValue];
    }];
    FImmutableTree *newSubtree = [[FImmutableTree alloc] initWithValue:subtree.value children:childrenDictionary];
    return [[FPruneForest alloc] initWithForest:[self.pruneForest setTree:newSubtree atPath:path]];
}

- (void)enumarateKeptNodesUsingBlock:(void (^)(FPath *))block {
    [self.pruneForest forEach:^(FPath *path, id value) {
        if (value != nil && ![value boolValue]) {
            block(path);
        }
    }];
}

@end
