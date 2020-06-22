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

#import "FirebaseDatabase/Sources/FListenComplete.h"
#import "FirebaseDatabase/Sources/Core/Operation/FOperationSource.h"
#import "FirebaseDatabase/Sources/Core/Utilities/FPath.h"

@interface FListenComplete ()
@property(nonatomic, strong, readwrite) FOperationSource *source;
@property(nonatomic, strong, readwrite) FPath *path;
@property(nonatomic, readwrite) FOperationType type;
@end

@implementation FListenComplete
- (id)initWithSource:(FOperationSource *)aSource path:(FPath *)aPath {
    NSAssert(!aSource.fromUser,
             @"Can't have a listen complete from a user source");
    self = [super init];
    if (self) {
        self.source = aSource;
        self.path = aPath;
        self.type = FOperationTypeListenComplete;
    }
    return self;
}

- (id<FOperation>)operationForChild:(NSString *)childKey {
    if ([self.path isEmpty]) {
        return [[FListenComplete alloc] initWithSource:self.source
                                                  path:[FPath empty]];
    } else {
        return [[FListenComplete alloc] initWithSource:self.source
                                                  path:[self.path popFront]];
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"FListenComplete { path=%@, source=%@ }",
                                      self.path, self.source];
}

@end
