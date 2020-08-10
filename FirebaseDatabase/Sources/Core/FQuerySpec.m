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

#import "FirebaseDatabase/Sources/Core/FQuerySpec.h"

@interface FQuerySpec ()

@property(nonatomic, strong, readwrite) FPath *path;
@property(nonatomic, strong, readwrite) FQueryParams *params;

@end

@implementation FQuerySpec

- (id)initWithPath:(FPath *)path params:(FQueryParams *)params {
    self = [super init];
    if (self != nil) {
        self->_path = path;
        self->_params = params;
    }
    return self;
}

+ (FQuerySpec *)defaultQueryAtPath:(FPath *)path {
    return [[FQuerySpec alloc] initWithPath:path
                                     params:[FQueryParams defaultInstance]];
}

- (id)copyWithZone:(NSZone *)zone {
    // Immutable
    return self;
}

- (id<FIndex>)index {
    return self.params.index;
}

- (BOOL)isDefault {
    return self.params.isDefault;
}

- (BOOL)loadsAllData {
    return self.params.loadsAllData;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[FQuerySpec class]]) {
        return NO;
    }

    FQuerySpec *other = (FQuerySpec *)object;

    if (![self.path isEqual:other.path]) {
        return NO;
    }

    return [self.params isEqual:other.params];
}

- (NSUInteger)hash {
    return self.path.hash * 31 + self.params.hash;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"FQuerySpec (path: %@, params: %@)",
                                      self.path, self.params];
}

@end
