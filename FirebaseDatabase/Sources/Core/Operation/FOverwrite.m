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

#import "FOverwrite.h"
#import "FNode.h"
#import "FOperationSource.h"

@interface FOverwrite ()
@property(nonatomic, strong, readwrite) FOperationSource *source;
@property(nonatomic, readwrite) FOperationType type;
@property(nonatomic, strong, readwrite) FPath *path;
@property(nonatomic, strong) id<FNode> snap;
@end

@implementation FOverwrite

@synthesize source;
@synthesize type;
@synthesize path;
@synthesize snap;

- (id)initWithSource:(FOperationSource *)aSource
                path:(FPath *)aPath
                snap:(id<FNode>)aSnap {
    self = [super init];
    if (self) {
        self.source = aSource;
        self.type = FOperationTypeOverwrite;
        self.path = aPath;
        self.snap = aSnap;
    }
    return self;
}

- (FOverwrite *)operationForChild:(NSString *)childKey {
    if ([self.path isEmpty]) {
        return [[FOverwrite alloc]
            initWithSource:self.source
                      path:[FPath empty]
                      snap:[self.snap getImmediateChild:childKey]];
    } else {
        return [[FOverwrite alloc] initWithSource:self.source
                                             path:[self.path popFront]
                                             snap:self.snap];
    }
}

- (NSString *)description {
    return [NSString
        stringWithFormat:@"FOverwrite { path=%@, source=%@, snapshot=%@ }",
                         self.path, self.source, self.snap];
}

@end
