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

#import "FirebaseDatabase/Sources/Core/Operation/FMerge.h"
#import "FirebaseDatabase/Sources/Core/Operation/FOperationSource.h"
#import "FirebaseDatabase/Sources/Core/Operation/FOverwrite.h"
#import "FirebaseDatabase/Sources/Core/Utilities/FPath.h"
#import "FirebaseDatabase/Sources/Snapshot/FCompoundWrite.h"
#import "FirebaseDatabase/Sources/Snapshot/FNode.h"

@interface FMerge ()
@property(nonatomic, strong, readwrite) FOperationSource *source;
@property(nonatomic, readwrite) FOperationType type;
@property(nonatomic, strong, readwrite) FPath *path;
@property(nonatomic, strong) FCompoundWrite *children;
@end

@implementation FMerge

@synthesize source;
@synthesize type;
@synthesize path;
@synthesize children;

- (id)initWithSource:(FOperationSource *)aSource
                path:(FPath *)aPath
            children:(FCompoundWrite *)someChildren {
    self = [super init];
    if (self) {
        self.source = aSource;
        self.type = FOperationTypeMerge;
        self.path = aPath;
        self.children = someChildren;
    }
    return self;
}

- (id<FOperation>)operationForChild:(NSString *)childKey {
    if ([self.path isEmpty]) {
        FCompoundWrite *childTree = [self.children
            childCompoundWriteAtPath:[[FPath alloc] initWith:childKey]];
        if (childTree.isEmpty) {
            return nil;
        } else if (childTree.rootWrite != nil) {
            // We have a snapshot for the child in question. This becomes an
            // overwrite of the child.
            return [[FOverwrite alloc] initWithSource:self.source
                                                 path:[FPath empty]
                                                 snap:childTree.rootWrite];
        } else {
            // This is a merge at a deeper level
            return [[FMerge alloc] initWithSource:self.source
                                             path:[FPath empty]
                                         children:childTree];
        }
    } else {
        NSAssert(
            [self.path.getFront isEqualToString:childKey],
            @"Can't get a merge for a child not on the path of the operation");
        return [[FMerge alloc] initWithSource:self.source
                                         path:[self.path popFront]
                                     children:self.children];
    }
}

- (NSString *)description {
    return
        [NSString stringWithFormat:@"FMerge { path=%@, soruce=%@ children=%@}",
                                   self.path, self.source, self.children];
}

@end
