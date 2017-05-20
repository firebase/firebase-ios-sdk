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

#import "FAckUserWrite.h"
#import "FPath.h"
#import "FOperationSource.h"
#import "FImmutableTree.h"


@implementation FAckUserWrite

- (id) initWithPath:(FPath *)operationPath affectedTree:(FImmutableTree *)tree revert:(BOOL)shouldRevert {
    self = [super init];
    if (self) {
        self->_source = [FOperationSource userInstance];
        self->_type = FOperationTypeAckUserWrite;
        self->_path = operationPath;
        self->_affectedTree = tree;
        self->_revert = shouldRevert;
    }
    return self;
}

- (FAckUserWrite *) operationForChild:(NSString *)childKey {
    if (![self.path isEmpty]) {
        NSAssert([self.path.getFront isEqualToString:childKey], @"operationForChild called for unrelated child.");
        return [[FAckUserWrite alloc] initWithPath:[self.path popFront] affectedTree:self.affectedTree revert:self.revert];
    } else if (self.affectedTree.value != nil) {
        NSAssert(self.affectedTree.children.isEmpty, @"affectedTree should not have overlapping affected paths.");
        // All child locations are affected as well; just return same operation.
        return self;
    } else {
        FImmutableTree *childTree = [self.affectedTree subtreeAtPath:[[FPath alloc] initWith:childKey]];
        return [[FAckUserWrite alloc] initWithPath:[FPath empty] affectedTree:childTree revert:self.revert];
    }
}

- (NSString *) description {
    return [NSString stringWithFormat:@"FAckUserWrite { path=%@, revert=%d, affectedTree=%@ }", self.path, self.revert, self.affectedTree];
}

@end
