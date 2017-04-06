//
//  APLevelDB.h
//
//  Created by Adam Preble on 1/23/12.
//  Copyright (c) 2012 Adam Preble. All rights reserved.
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights
//	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//	copies of the Software, and to permit persons to whom the Software is
//	furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in
//	all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//	THE SOFTWARE.

#import <Foundation/Foundation.h>

extern NSString * const APLevelDBErrorDomain;

@class APLevelDBIterator;
@protocol APLevelDBWriteBatch;

@interface APLevelDB : NSObject

@property (nonatomic, readonly, strong) NSString *path;

+ (APLevelDB *)levelDBWithPath:(NSString *)path error:(NSError *__autoreleasing*)errorOut;
- (void)close;

- (BOOL)setData:(NSData *)data forKey:(NSString *)key;
- (BOOL)setString:(NSString *)str forKey:(NSString *)key;

- (NSData *)dataForKey:(NSString *)key;
- (NSString *)stringForKey:(NSString *)key;

- (BOOL)removeKey:(NSString *)key;

- (NSArray *)allKeys;

- (void)enumerateKeys:(void (^)(NSString *key, BOOL *stop))block;
- (void)enumerateKeysWithPrefix:(NSString *)prefix usingBlock:(void (^)(NSString *key, BOOL *stop))block;

- (void)enumerateKeysAndValuesAsStrings:(void (^)(NSString *key, NSString *value, BOOL *stop))block;
- (void)enumerateKeysWithPrefix:(NSString *)prefix asStrings:(void (^)(NSString *key, NSString *value, BOOL *stop))block;

- (void)enumerateKeysAndValuesAsData:(void (^)(NSString *key, NSData *value, BOOL *stop))block;
- (void)enumerateKeysWithPrefix:(NSString *)prefix asData:(void (^)(NSString *key, NSData *value, BOOL *stop))block;

- (NSUInteger)approximateSizeFrom:(NSString *)from to:(NSString *)to;
- (NSUInteger)exactSizeFrom:(NSString *)from to:(NSString *)to;

// Objective-C Subscripting Support:
//   The database object supports subscripting for string-string and string-data key-value access and assignment.
//   Examples:
//     db[@"key"] = @"value";
//     db[@"key"] = [NSData data];
//     NSString *s = db[@"key"];
//   An NSInvalidArgumentException is raised if the key is not an NSString, or if the assigned object is not an
//   instance of NSString or NSData.
- (id)objectForKeyedSubscript:(id)key;
- (void)setObject:(id)object forKeyedSubscript:(id<NSCopying>)key;

// Batch write/atomic update support:
- (id<APLevelDBWriteBatch>)beginWriteBatch;

@end


@interface APLevelDBIterator : NSObject

+ (id)iteratorWithLevelDB:(APLevelDB *)db;

// Designated initializer:
- (id)initWithLevelDB:(APLevelDB *)db;

- (BOOL)seekToKey:(NSString *)key;
- (NSString *)nextKey;
- (NSString *)key;
- (NSString *)valueAsString;
- (NSData *)valueAsData;

@end


@protocol APLevelDBWriteBatch <NSObject>

- (void)setData:(NSData *)data forKey:(NSString *)key;
- (void)setString:(NSString *)str forKey:(NSString *)key;

- (void)removeKey:(NSString *)key;

// Remove all of the buffered sets and removes:
- (void)clear;
- (BOOL)commit;

@end
