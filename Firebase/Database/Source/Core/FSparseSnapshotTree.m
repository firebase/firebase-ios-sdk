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

#import "FSparseSnapshotTree.h"
#import "FChildrenNode.h"

@interface FSparseSnapshotTree () {
    id<FNode> value;
    NSMutableDictionary* children;
}

@end

@implementation FSparseSnapshotTree

- (id) init {
    self = [super init];
    if (self) {
        value = nil;
        children = nil;
    }
    return self;
}

- (id<FNode>) findPath:(FPath *)path {
    if (value != nil) {
        return [value getChild:path];
    } else if (![path isEmpty] && children != nil) {
        NSString* childKey = [path getFront];
        path = [path popFront];
        FSparseSnapshotTree* childTree = children[childKey];
        if (childTree != nil) {
            return [childTree findPath:path];
        } else {
            return nil;
        }
    } else {
        return nil;
    }
}

- (void) rememberData:(id<FNode>)data onPath:(FPath *)path {
    if ([path isEmpty]) {
        value = data;
        children = nil;
    } else if (value != nil) {
        value = [value updateChild:path withNewChild:data];
    } else {
        if (children == nil) {
            children = [[NSMutableDictionary alloc] init];
        }

        NSString* childKey = [path getFront];
        if (children[childKey] == nil) {
            children[childKey] = [[FSparseSnapshotTree alloc] init];
        }

        FSparseSnapshotTree* child = children[childKey];
        path = [path popFront];
        [child rememberData:data onPath:path];
    }
}

- (BOOL) forgetPath:(FPath *)path {
    if ([path isEmpty]) {
        value = nil;
        children = nil;
        return YES;
    } else {
        if (value != nil) {
            if ([value isLeafNode]) {
                // non-empty path at leaf. the path leads to nowhere
                return NO;
            } else {
                id<FNode> tmp = value;
                value = nil;

                [tmp enumerateChildrenUsingBlock:^(NSString *key, id<FNode> node, BOOL *stop) {
                    [self rememberData:node onPath:[[FPath alloc] initWith:key]];
                }];

                // we've cleared out the value and set children. Call ourself again to hit the next case
                return [self forgetPath:path];
            }
        } else if (children != nil) {
            NSString* childKey = [path getFront];
            path = [path popFront];

            if (children[childKey] != nil) {
                FSparseSnapshotTree* child = children[childKey];
                BOOL safeToRemove = [child forgetPath:path];
                if (safeToRemove) {
                    [children removeObjectForKey:childKey];
                }
            }

            if ([children count] == 0) {
                children = nil;
                return YES;
            } else {
                return NO;
            }
        } else {
            return YES;
        }
    }
}

- (void) forEachTreeAtPath:(FPath *)prefixPath do:(fbt_void_path_node)func {
    if (value != nil) {
        func(prefixPath, value);
    } else {
        [self forEachChild:^(NSString* key, FSparseSnapshotTree* tree) {
            FPath* path = [prefixPath childFromString:key];
            [tree forEachTreeAtPath:path do:func];
        }];
    }
}


- (void) forEachChild:(fbt_void_nsstring_sstree)func {
    if (children != nil) {
        for (NSString* key in children) {
            FSparseSnapshotTree* tree = [children objectForKey:key];
            func(key, tree);
        }
    }
}


@end
