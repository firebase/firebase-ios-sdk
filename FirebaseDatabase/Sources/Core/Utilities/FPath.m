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

#import "FirebaseDatabase/Sources/Core/Utilities/FPath.h"

#import "FirebaseDatabase/Sources/Utilities/FUtilities.h"

@interface FPath ()

@property(nonatomic, readwrite, assign) NSInteger pieceNum;
@property(nonatomic, strong) NSArray *pieces;

@end

@implementation FPath

#pragma mark -
#pragma mark Initializers

+ (FPath *)relativePathFrom:(FPath *)outer to:(FPath *)inner {
    NSString *outerFront = [outer getFront];
    NSString *innerFront = [inner getFront];
    if (outerFront == nil) {
        return inner;
    } else if ([outerFront isEqualToString:innerFront]) {
        return [self relativePathFrom:[outer popFront] to:[inner popFront]];
    } else {
        @throw [[NSException alloc]
            initWithName:@"FirebaseDatabaseInternalError"
                  reason:[NSString
                             stringWithFormat:
                                 @"innerPath (%@) is not within outerPath (%@)",
                                 inner, outer]
                userInfo:nil];
    }
}

+ (FPath *)pathWithString:(NSString *)string {
    return [[FPath alloc] initWith:string];
}

- (id)initWith:(NSString *)path {
    self = [super init];
    if (self) {
        NSArray *pathPieces = [path componentsSeparatedByString:@"/"];
        NSMutableArray *newPieces = [[NSMutableArray alloc] init];
        for (NSInteger i = 0; i < pathPieces.count; i++) {
            NSString *piece = [pathPieces objectAtIndex:i];
            if (piece.length > 0) {
                [newPieces addObject:piece];
            }
        }

        self.pieces = newPieces;
        self.pieceNum = 0;
    }
    return self;
}

- (id)initWithPieces:(NSArray *)somePieces andPieceNum:(NSInteger)aPieceNum {
    self = [super init];
    if (self) {
        self.pieceNum = aPieceNum;
        self.pieces = somePieces;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    // Immutable, so it's safe to return self
    return self;
}

- (NSString *)description {
    return [self toString];
}

#pragma mark -
#pragma mark Public methods

- (NSString *)getFront {
    if (self.pieceNum >= self.pieces.count) {
        return nil;
    }
    return [self.pieces objectAtIndex:self.pieceNum];
}

/**
 * @return The number of segments in this path
 */
- (NSUInteger)length {
    return self.pieces.count - self.pieceNum;
}

- (FPath *)popFront {
    NSInteger newPieceNum = self.pieceNum;
    if (newPieceNum < self.pieces.count) {
        newPieceNum++;
    }
    return [[FPath alloc] initWithPieces:self.pieces andPieceNum:newPieceNum];
}

- (NSString *)getBack {
    if (self.pieceNum < self.pieces.count) {
        return [self.pieces lastObject];
    } else {
        return nil;
    }
}

- (NSString *)toString {
    return [self toStringWithTrailingSlash:NO];
}

- (NSString *)toStringWithTrailingSlash {
    return [self toStringWithTrailingSlash:YES];
}

- (NSString *)toStringWithTrailingSlash:(BOOL)trailingSlash {
    NSMutableString *pathString = [[NSMutableString alloc] init];
    for (NSInteger i = self.pieceNum; i < self.pieces.count; i++) {
        [pathString appendString:@"/"];
        [pathString appendString:[self.pieces objectAtIndex:i]];
    }
    if ([pathString length] == 0) {
        return @"/";
    } else {
        if (trailingSlash) {
            [pathString appendString:@"/"];
        }
        return pathString;
    }
}

- (NSString *)wireFormat {
    if ([self isEmpty]) {
        return @"/";
    } else {
        NSMutableString *pathString = [[NSMutableString alloc] init];
        for (NSInteger i = self.pieceNum; i < self.pieces.count; i++) {
            if (i > self.pieceNum) {
                [pathString appendString:@"/"];
            }
            [pathString appendString:[self.pieces objectAtIndex:i]];
        }
        return pathString;
    }
}

- (FPath *)parent {
    if (self.pieceNum >= self.pieces.count) {
        return nil;
    } else {
        NSMutableArray *newPieces = [[NSMutableArray alloc] init];
        for (NSInteger i = self.pieceNum; i < self.pieces.count - 1; i++) {
            [newPieces addObject:[self.pieces objectAtIndex:i]];
        }
        return [[FPath alloc] initWithPieces:newPieces andPieceNum:0];
    }
}

- (FPath *)child:(FPath *)childPathObj {
    NSMutableArray *newPieces = [[NSMutableArray alloc] init];
    for (NSInteger i = self.pieceNum; i < self.pieces.count; i++) {
        [newPieces addObject:[self.pieces objectAtIndex:i]];
    }

    for (NSInteger i = childPathObj.pieceNum; i < childPathObj.pieces.count;
         i++) {
        [newPieces addObject:[childPathObj.pieces objectAtIndex:i]];
    }

    return [[FPath alloc] initWithPieces:newPieces andPieceNum:0];
}

- (FPath *)childFromString:(NSString *)childPath {
    NSMutableArray *newPieces = [[NSMutableArray alloc] init];
    for (NSInteger i = self.pieceNum; i < self.pieces.count; i++) {
        [newPieces addObject:[self.pieces objectAtIndex:i]];
    }

    NSArray *pathPieces = [childPath componentsSeparatedByString:@"/"];
    for (unsigned int i = 0; i < pathPieces.count; i++) {
        NSString *piece = [pathPieces objectAtIndex:i];
        if (piece.length > 0) {
            [newPieces addObject:piece];
        }
    }

    return [[FPath alloc] initWithPieces:newPieces andPieceNum:0];
}

/**
 * @return True if there are no segments in this path
 */
- (BOOL)isEmpty {
    return self.pieceNum >= self.pieces.count;
}

/**
 * @return Singleton to represent an empty path
 */
+ (FPath *)empty {
    static dispatch_once_t oneEmptyPath;
    static FPath *emptyPath;
    dispatch_once(&oneEmptyPath, ^{
      emptyPath = [[FPath alloc] initWith:@""];
    });
    return emptyPath;
}

- (BOOL)contains:(FPath *)other {
    if (self.length > other.length) {
        return NO;
    }

    NSInteger i = self.pieceNum;
    NSInteger j = other.pieceNum;
    while (i < self.pieces.count) {
        NSString *thisSeg = [self.pieces objectAtIndex:i];
        NSString *otherSeg = [other.pieces objectAtIndex:j];
        if (![thisSeg isEqualToString:otherSeg]) {
            return NO;
        }
        ++i;
        ++j;
    }
    return YES;
}

- (void)enumerateComponentsUsingBlock:(void (^)(NSString *, BOOL *))block {
    BOOL stop = NO;
    for (NSInteger i = self.pieceNum; !stop && i < self.pieces.count; i++) {
        block(self.pieces[i], &stop);
    }
}

- (NSComparisonResult)compare:(FPath *)other {
    NSInteger myCount = self.pieces.count;
    NSInteger otherCount = other.pieces.count;
    for (NSInteger i = self.pieceNum, j = other.pieceNum;
         i < myCount && j < otherCount; i++, j++) {
        NSComparisonResult comparison = [FUtilities compareKey:self.pieces[i]
                                                         toKey:other.pieces[j]];
        if (comparison != NSOrderedSame) {
            return comparison;
        }
    }
    if (self.length < other.length) {
        return NSOrderedAscending;
    } else if (other.length < self.length) {
        return NSOrderedDescending;
    } else {
        NSAssert(self.length == other.length,
                 @"Paths must be the same lengths");
        return NSOrderedSame;
    }
}

/**
 * @return YES if paths are the same
 */
- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    }
    if (!other || ![other isKindOfClass:[self class]]) {
        return NO;
    }
    FPath *otherPath = (FPath *)other;
    if (self.length != otherPath.length) {
        return NO;
    }
    for (NSUInteger i = self.pieceNum, j = otherPath.pieceNum;
         i < self.pieces.count; i++, j++) {
        if (![self.pieces[i] isEqualToString:otherPath.pieces[j]]) {
            return NO;
        }
    }
    return YES;
}

- (NSUInteger)hash {
    NSUInteger hashCode = 0;
    for (NSInteger i = self.pieceNum; i < self.pieces.count; i++) {
        hashCode = hashCode * 37 + [self.pieces[i] hash];
    }
    return hashCode;
}

@end
