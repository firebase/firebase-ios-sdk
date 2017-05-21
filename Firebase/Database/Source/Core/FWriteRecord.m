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

#import "FWriteRecord.h"
#import "FPath.h"
#import "FNode.h"
#import "FCompoundWrite.h"

@interface FWriteRecord ()
@property (nonatomic, readwrite) NSInteger writeId;
@property (nonatomic, strong, readwrite) FPath *path;
@property (nonatomic, strong, readwrite) id<FNode> overwrite;
@property (nonatomic, strong, readwrite) FCompoundWrite *merge;
@property (nonatomic, readwrite) BOOL visible;
@end

@implementation FWriteRecord

- (id)initWithPath:(FPath *)path overwrite:(id<FNode>)overwrite writeId:(NSInteger)writeId visible:(BOOL)isVisible {
    self = [super init];
    if (self) {
        self.path = path;
        if (overwrite == nil) {
            [NSException raise:NSInvalidArgumentException format:@"Can't pass nil as overwrite parameter to an overwrite write record"];
        }
        self.overwrite = overwrite;
        self.merge = nil;
        self.writeId = writeId;
        self.visible = isVisible;
    }
    return self;
}

- (id)initWithPath:(FPath *)path merge:(FCompoundWrite *)merge writeId:(NSInteger)writeId {
    self = [super init];
    if (self) {
        self.path = path;
        if (merge == nil) {
            [NSException raise:NSInvalidArgumentException format:@"Can't pass nil as merge parameter to an merge write record"];
        }
        self.overwrite = nil;
        self.merge = merge;
        self.writeId = writeId;
        self.visible = YES;
    }
    return self;
}

- (id<FNode>)overwrite {
    if (self->_overwrite == nil) {
        [NSException raise:NSInvalidArgumentException format:@"Can't get overwrite for merge write record!"];
    }
    return self->_overwrite;
}

- (FCompoundWrite *)compoundWrite {
    if (self->_merge == nil) {
        [NSException raise:NSInvalidArgumentException format:@"Can't get merge for overwrite write record!"];
    }
    return self->_merge;
}

- (BOOL)isMerge {
    return self->_merge != nil;
}

- (BOOL)isOverwrite {
    return self->_overwrite != nil;
}

- (NSString *)description {
    if (self.isOverwrite) {
        return [NSString stringWithFormat:@"FWriteRecord { writeId = %lu, path = %@, overwrite = %@, visible = %d }",
                (unsigned long)self.writeId, self.path, self.overwrite, self.visible];
    } else {
        return [NSString stringWithFormat:@"FWriteRecord { writeId = %lu, path = %@, merge = %@ }",
                (unsigned long)self.writeId, self.path, self.merge];
    }
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[self class]]) {
        return NO;
    }
    FWriteRecord *other = (FWriteRecord *)object;
    if (self->_writeId != other->_writeId) return NO;
    if (self->_path != other->_path && ![self->_path isEqual:other->_path]) return NO;
    if (self->_overwrite != other->_overwrite && ![self->_overwrite isEqual:other->_overwrite]) return NO;
    if (self->_merge != other->_merge && ![self->_merge isEqual:other->_merge]) return NO;
    if (self->_visible != other->_visible) return NO;

    return YES;
}

- (NSUInteger)hash {
    NSUInteger hash = self->_writeId * 17;
    hash = hash * 31 + self->_path.hash;
    hash = hash * 31 + self->_overwrite.hash;
    hash = hash * 31 + self->_merge.hash;
    hash = hash * 31 + ((self->_visible) ? 1 : 0);
    return hash;
}

@end
