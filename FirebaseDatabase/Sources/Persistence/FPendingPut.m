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

#import "FPendingPut.h"

@implementation FPendingPut

@synthesize path;
@synthesize data;

- (id)initWithPath:(FPath *)aPath andData:(id)aData andPriority:(id)aPriority {
    self = [super init];
    if (self) {
        self.path = aPath;
        self.data = aData;
        self.priority = aPriority;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:[self.path description] forKey:@"path"];
    [aCoder encodeObject:self.data forKey:@"data"];
    [aCoder encodeObject:self.priority forKey:@"priority"];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        self.path =
            [[FPath alloc] initWith:[aDecoder decodeObjectForKey:@"path"]];
        self.data = [aDecoder decodeObjectForKey:@"data"];
        self.priority = [aDecoder decodeObjectForKey:@"priority"];
    }
    return self;
}

@end

@implementation FPendingPutPriority

@synthesize path;
@synthesize priority;

- (id)initWithPath:(FPath *)aPath andPriority:(id)aPriority {
    self = [super init];
    if (self) {
        self.path = aPath;
        self.priority = aPriority;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:[self.path description] forKey:@"path"];
    [aCoder encodeObject:self.priority forKey:@"priority"];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        self.path =
            [[FPath alloc] initWith:[aDecoder decodeObjectForKey:@"path"]];
        self.priority = [aDecoder decodeObjectForKey:@"priority"];
    }
    return self;
}

@end

@implementation FPendingUpdate

@synthesize path;
@synthesize data;

- (id)initWithPath:(FPath *)aPath andData:(id)aData {
    self = [super init];
    if (self) {
        self.path = aPath;
        self.data = aData;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:[self.path description] forKey:@"path"];
    [aCoder encodeObject:self.data forKey:@"data"];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        self.path =
            [[FPath alloc] initWith:[aDecoder decodeObjectForKey:@"path"]];
        self.data = [aDecoder decodeObjectForKey:@"data"];
    }
    return self;
}

@end
