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

#import <Foundation/Foundation.h>

@interface FPath : NSObject <NSCopying>

+ (FPath *)relativePathFrom:(FPath *)outer to:(FPath *)inner;
+ (FPath *)empty;
+ (FPath *)pathWithString:(NSString *)string;

- (id)initWith:(NSString *)path;
- (id)initWithPieces:(NSArray *)somePieces andPieceNum:(NSInteger)aPieceNum;

- (id)copyWithZone:(NSZone *)zone;

- (void)enumerateComponentsUsingBlock:(void (^)(NSString *key,
                                                BOOL *stop))block;
- (NSString *)getFront;
- (NSUInteger)length;
- (FPath *)popFront;
- (NSString *)getBack;
- (NSString *)toString;
- (NSString *)toStringWithTrailingSlash;
- (NSString *)wireFormat;
- (FPath *)parent;
- (FPath *)child:(FPath *)childPathObj;
- (FPath *)childFromString:(NSString *)childPath;
- (BOOL)isEmpty;
- (BOOL)contains:(FPath *)other;
- (NSComparisonResult)compare:(FPath *)other;

@end
