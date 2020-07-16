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

#import "FirebaseDatabase/Sources/Core/Utilities/FImmutableTree.h"
#import "FirebaseDatabase/Sources/Core/Utilities/FPath.h"
#import "FirebaseDatabase/Sources/Utilities/FUtilities.h"
#import "FirebaseDatabase/Sources/third_party/FImmutableSortedDictionary/FImmutableSortedDictionary/FImmutableSortedDictionary.h"

@interface FImmutableTree ()
@property(nonatomic, strong, readwrite) id value;
/**
 * Maps NSString -> FImmutableTree<T>, where <T> is type of value.
 */
@property(nonatomic, strong, readwrite) FImmutableSortedDictionary *children;
@end

@implementation FImmutableTree
@synthesize value;
@synthesize children;

- (id)initWithValue:(id)aValue {
    self = [super init];
    if (self) {
        self.value = aValue;
        self.children = [FImmutableTree emptyChildren];
    }
    return self;
}

- (id)initWithValue:(id)aValue
           children:(FImmutableSortedDictionary *)childrenMap {
    self = [super init];
    if (self) {
        self.value = aValue;
        self.children = childrenMap;
    }
    return self;
}

+ (FImmutableSortedDictionary *)emptyChildren {
    static dispatch_once_t emptyChildrenToken;
    static FImmutableSortedDictionary *emptyChildren;
    dispatch_once(&emptyChildrenToken, ^{
      emptyChildren = [FImmutableSortedDictionary
          dictionaryWithComparator:[FUtilities stringComparator]];
    });
    return emptyChildren;
}

+ (FImmutableTree *)empty {
    static dispatch_once_t emptyImmutableTreeToken;
    static FImmutableTree *emptyTree = nil;
    dispatch_once(&emptyImmutableTreeToken, ^{
      emptyTree = [[FImmutableTree alloc] initWithValue:nil];
    });
    return emptyTree;
}

- (BOOL)isEmpty {
    return self.value == nil && [self.children isEmpty];
}

/**
 * Given a path and a predicate, return the first node and the path to that node
 * where the predicate returns true
 * // TODO Do a perf test. If we're creating a bunch of FTuplePathValue objects
 * on the way back out, it may be better to pass down a pathSoFar FPath
 */
- (FTuplePathValue *)findRootMostMatchingPath:(FPath *)relativePath
                                    predicate:(BOOL (^)(id value))predicate {
    if (self.value != nil && predicate(self.value)) {
        return [[FTuplePathValue alloc] initWithPath:[FPath empty]
                                               value:self.value];
    } else {
        if ([relativePath isEmpty]) {
            return nil;
        } else {
            NSString *front = [relativePath getFront];
            FImmutableTree *child = [self.children get:front];
            if (child != nil) {
                FTuplePathValue *childExistingPathAndValue =
                    [child findRootMostMatchingPath:[relativePath popFront]
                                          predicate:predicate];
                if (childExistingPathAndValue != nil) {
                    FPath *fullPath = [[[FPath alloc] initWith:front]
                        child:childExistingPathAndValue.path];
                    return [[FTuplePathValue alloc]
                        initWithPath:fullPath
                               value:childExistingPathAndValue.value];
                } else {
                    return nil;
                }
            } else {
                // No child matching path
                return nil;
            }
        }
    }
}

/**
 * Find, if it exists, the shortest subpath of the given path that points a
 * defined value in the tree
 */
- (FTuplePathValue *)findRootMostValueAndPath:(FPath *)relativePath {
    return [self findRootMostMatchingPath:relativePath
                                predicate:^BOOL(__unsafe_unretained id value) {
                                  return YES;
                                }];
}

- (id)rootMostValueOnPath:(FPath *)path {
    return [self rootMostValueOnPath:path
                            matching:^BOOL(id value) {
                              return YES;
                            }];
}

- (id)rootMostValueOnPath:(FPath *)path matching:(BOOL (^)(id))predicate {
    if (self.value != nil && predicate(self.value)) {
        return self.value;
    } else if (path.isEmpty) {
        return nil;
    } else {
        return [[self.children get:path.getFront]
            rootMostValueOnPath:[path popFront]
                       matching:predicate];
    }
}

- (id)leafMostValueOnPath:(FPath *)path {
    return [self leafMostValueOnPath:path
                            matching:^BOOL(id value) {
                              return YES;
                            }];
}

- (id)leafMostValueOnPath:(FPath *)relativePath
                 matching:(BOOL (^)(id))predicate {
    __block id currentValue = self.value;
    __block FImmutableTree *currentTree = self;
    [relativePath enumerateComponentsUsingBlock:^(NSString *key, BOOL *stop) {
      currentTree = [currentTree.children get:key];
      if (currentTree == nil) {
          *stop = YES;
      } else {
          id treeValue = currentTree.value;
          if (treeValue != nil && predicate(treeValue)) {
              currentValue = treeValue;
          }
      }
    }];
    return currentValue;
}

- (BOOL)containsValueMatching:(BOOL (^)(id))predicate {
    if (self.value != nil && predicate(self.value)) {
        return YES;
    } else {
        __block BOOL found = NO;
        [self.children enumerateKeysAndObjectsUsingBlock:^(
                           NSString *key, FImmutableTree *subtree, BOOL *stop) {
          found = [subtree containsValueMatching:predicate];
          if (found)
              *stop = YES;
        }];
        return found;
    }
}

- (FImmutableTree *)subtreeAtPath:(FPath *)relativePath {
    if ([relativePath isEmpty]) {
        return self;
    } else {
        NSString *front = [relativePath getFront];
        FImmutableTree *childTree = [self.children get:front];
        if (childTree != nil) {
            return [childTree subtreeAtPath:[relativePath popFront]];
        } else {
            return [FImmutableTree empty];
        }
    }
}

/**
 * Sets a value at the specified path
 */
- (FImmutableTree *)setValue:(id)newValue atPath:(FPath *)relativePath {
    if ([relativePath isEmpty]) {
        return [[FImmutableTree alloc] initWithValue:newValue
                                            children:self.children];
    } else {
        NSString *front = [relativePath getFront];
        FImmutableTree *child = [self.children get:front];
        if (child == nil) {
            child = [FImmutableTree empty];
        }
        FImmutableTree *newChild = [child setValue:newValue
                                            atPath:[relativePath popFront]];
        FImmutableSortedDictionary *newChildren =
            [self.children insertKey:front withValue:newChild];
        return [[FImmutableTree alloc] initWithValue:self.value
                                            children:newChildren];
    }
}

/**
 * Remove the value at the specified path
 */
- (FImmutableTree *)removeValueAtPath:(FPath *)relativePath {
    if ([relativePath isEmpty]) {
        if ([self.children isEmpty]) {
            return [FImmutableTree empty];
        } else {
            return [[FImmutableTree alloc] initWithValue:nil
                                                children:self.children];
        }
    } else {
        NSString *front = [relativePath getFront];
        FImmutableTree *child = [self.children get:front];
        if (child) {
            FImmutableTree *newChild =
                [child removeValueAtPath:[relativePath popFront]];
            FImmutableSortedDictionary *newChildren;
            if ([newChild isEmpty]) {
                newChildren = [self.children removeKey:front];
            } else {
                newChildren = [self.children insertKey:front
                                             withValue:newChild];
            }
            if (self.value == nil && [newChildren isEmpty]) {
                return [FImmutableTree empty];
            } else {
                return [[FImmutableTree alloc] initWithValue:self.value
                                                    children:newChildren];
            }
        } else {
            return self;
        }
    }
}

/**
 * Gets a value from the tree
 */
- (id)valueAtPath:(FPath *)relativePath {
    if ([relativePath isEmpty]) {
        return self.value;
    } else {
        NSString *front = [relativePath getFront];
        FImmutableTree *child = [self.children get:front];
        if (child) {
            return [child valueAtPath:[relativePath popFront]];
        } else {
            return nil;
        }
    }
}

/**
 * Replaces the subtree at the specified path with the given new tree
 */
- (FImmutableTree *)setTree:(FImmutableTree *)newTree
                     atPath:(FPath *)relativePath {
    if ([relativePath isEmpty]) {
        return newTree;
    } else {
        NSString *front = [relativePath getFront];
        FImmutableTree *child = [self.children get:front];
        if (child == nil) {
            child = [FImmutableTree empty];
        }
        FImmutableTree *newChild = [child setTree:newTree
                                           atPath:[relativePath popFront]];
        FImmutableSortedDictionary *newChildren;
        if ([newChild isEmpty]) {
            newChildren = [self.children removeKey:front];
        } else {
            newChildren = [self.children insertKey:front withValue:newChild];
        }
        return [[FImmutableTree alloc] initWithValue:self.value
                                            children:newChildren];
    }
}

/**
 * Performs a depth first fold on this tree. Transforms a tree into a single
 * value, given a function that operates on the path to a node, an optional
 * current value, and a map of the child names to folded subtrees
 */
- (id)foldWithBlock:(id (^)(FPath *path, id value,
                            NSDictionary *foldedChildren))block {
    return [self foldWithPathSoFar:[FPath empty] withBlock:block];
}

/**
 * Recursive helper for public facing foldWithBlock: method
 */
- (id)foldWithPathSoFar:(FPath *)pathSoFar
              withBlock:(id (^)(FPath *path, id value,
                                NSDictionary *foldedChildren))block {
    __block NSMutableDictionary *accum = [[NSMutableDictionary alloc] init];
    [self.children
        enumerateKeysAndObjectsUsingBlock:^(
            NSString *childKey, FImmutableTree *childTree, BOOL *stop) {
          accum[childKey] =
              [childTree foldWithPathSoFar:[pathSoFar childFromString:childKey]
                                 withBlock:block];
        }];
    return block(pathSoFar, self.value, accum);
}

/**
 * Find the first matching value on the given path. Return the result of
 * applying block to it.
 */
- (id)findOnPath:(FPath *)path
    andApplyBlock:(id (^)(FPath *path, id value))block {
    return [self findOnPath:path pathSoFar:[FPath empty] andApplyBlock:block];
}

- (id)findOnPath:(FPath *)pathToFollow
        pathSoFar:(FPath *)pathSoFar
    andApplyBlock:(id (^)(FPath *path, id value))block {
    id result = self.value ? block(pathSoFar, self.value) : nil;
    if (result != nil) {
        return result;
    } else {
        if ([pathToFollow isEmpty]) {
            return nil;
        } else {
            NSString *front = [pathToFollow getFront];
            FImmutableTree *nextChild = [self.children get:front];
            if (nextChild != nil) {
                return [nextChild findOnPath:[pathToFollow popFront]
                                   pathSoFar:[pathSoFar childFromString:front]
                               andApplyBlock:block];
            } else {
                return nil;
            }
        }
    }
}
/**
 * Call the block on each value along the path for as long as that function
 * returns true
 * @return The path to the deepest location inspected
 */
- (FPath *)forEachOnPath:(FPath *)path whileBlock:(BOOL (^)(FPath *, id))block {
    return [self forEachOnPath:path pathSoFar:[FPath empty] whileBlock:block];
}

- (FPath *)forEachOnPath:(FPath *)pathToFollow
               pathSoFar:(FPath *)pathSoFar
              whileBlock:(BOOL (^)(FPath *, id))block {
    if ([pathToFollow isEmpty]) {
        if (self.value) {
            block(pathSoFar, self.value);
        }
        return pathSoFar;
    } else {
        BOOL shouldContinue = YES;
        if (self.value) {
            shouldContinue = block(pathSoFar, self.value);
        }
        if (shouldContinue) {
            NSString *front = [pathToFollow getFront];
            FImmutableTree *nextChild = [self.children get:front];
            if (nextChild) {
                return
                    [nextChild forEachOnPath:[pathToFollow popFront]
                                   pathSoFar:[pathSoFar childFromString:front]
                                  whileBlock:block];
            } else {
                return pathSoFar;
            }
        } else {
            return pathSoFar;
        }
    }
}

- (FImmutableTree *)forEachOnPath:(FPath *)path
                     performBlock:(void (^)(FPath *path, id value))block {
    return [self forEachOnPath:path pathSoFar:[FPath empty] performBlock:block];
}

- (FImmutableTree *)forEachOnPath:(FPath *)pathToFollow
                        pathSoFar:(FPath *)pathSoFar
                     performBlock:(void (^)(FPath *path, id value))block {
    if ([pathToFollow isEmpty]) {
        return self;
    } else {
        if (self.value) {
            block(pathSoFar, self.value);
        }
        NSString *front = [pathToFollow getFront];
        FImmutableTree *nextChild = [self.children get:front];
        if (nextChild) {
            return [nextChild forEachOnPath:[pathToFollow popFront]
                                  pathSoFar:[pathSoFar childFromString:front]
                               performBlock:block];
        } else {
            return [FImmutableTree empty];
        }
    }
}
/**
 * Calls the given block for each node in the tree that has a value. Called in
 * depth-first order
 */
- (void)forEach:(void (^)(FPath *path, id value))block {
    [self forEachPathSoFar:[FPath empty] withBlock:block];
}

- (void)forEachPathSoFar:(FPath *)pathSoFar
               withBlock:(void (^)(FPath *path, id value))block {
    [self.children
        enumerateKeysAndObjectsUsingBlock:^(
            NSString *childKey, FImmutableTree *childTree, BOOL *stop) {
          [childTree forEachPathSoFar:[pathSoFar childFromString:childKey]
                            withBlock:block];
        }];
    if (self.value) {
        block(pathSoFar, self.value);
    }
}

- (void)forEachChild:(void (^)(NSString *childKey, id childValue))block {
    [self.children
        enumerateKeysAndObjectsUsingBlock:^(
            NSString *childKey, FImmutableTree *childTree, BOOL *stop) {
          if (childTree.value) {
              block(childKey, childTree.value);
          }
        }];
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[FImmutableTree class]]) {
        return NO;
    }
    FImmutableTree *other = (FImmutableTree *)object;
    return (self.value == other.value || [self.value isEqual:other.value]) &&
           [self.children isEqual:other.children];
}

- (NSUInteger)hash {
    return self.children.hash * 31 + [self.value hash];
}

- (NSString *)description {
    NSMutableString *string = [[NSMutableString alloc] init];
    [string appendString:@"FImmutableTree { value="];
    [string appendString:(self.value ? [self.value description] : @"<nil>")];
    [string appendString:@", children={"];
    [self.children
        enumerateKeysAndObjectsUsingBlock:^(
            NSString *childKey, FImmutableTree *childTree, BOOL *stop) {
          [string appendString:@" "];
          [string appendString:childKey];
          [string appendString:@"="];
          [string appendString:[childTree.value description]];
        }];
    [string appendString:@" } }"];
    return [NSString stringWithString:string];
}

- (NSString *)debugDescription {
    return [self description];
}

@end
