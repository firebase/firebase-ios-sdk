//
//  APLevelDB.m
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

//
//  Portions of APLevelDB are based on LevelDB-ObjC:
//	https://github.com/hoisie/LevelDB-ObjC
//  Specifically the SliceFromString/StringFromSlice macros, and the structure of
//  the enumeration methods.  License for those potions follows:
//
//	Copyright (c) 2011 Pave Labs
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
//

#import "FirebaseDatabase/Sources/third_party/Wrap-leveldb/APLevelDB.h"

#import "leveldb/db.h"
#import "leveldb/options.h"
#import "leveldb/write_batch.h"

NSString * const APLevelDBErrorDomain = @"APLevelDBErrorDomain";

#define SliceFromString(_string_) (leveldb::Slice((char *)[_string_ UTF8String], [_string_ lengthOfBytesUsingEncoding:NSUTF8StringEncoding]))
#define StringFromSlice(_slice_) ([[NSString alloc] initWithBytes:_slice_.data() length:_slice_.size() encoding:NSUTF8StringEncoding])


@interface APLevelDBWriteBatch : NSObject <APLevelDBWriteBatch> {
    @package
    leveldb::WriteBatch _batch;
}

@property (nonatomic, strong) APLevelDB *levelDB;

- (id)initWithLevelDB:(APLevelDB *)levelDB;
@end


#pragma mark - APLevelDB

@interface APLevelDB () {
    leveldb::DB *_db;
    leveldb::ReadOptions _readOptions;
    leveldb::WriteOptions _writeOptions;
}
- (id)initWithPath:(NSString *)path error:(NSError **)errorOut;
+ (leveldb::Options)defaultCreateOptions;
@property (nonatomic, readonly) leveldb::DB *db;
@end


@implementation APLevelDB

@synthesize path = _path;
@synthesize db = _db;

+ (APLevelDB *)levelDBWithPath:(NSString *)path error:(NSError *__autoreleasing *)errorOut
{
    return [[APLevelDB alloc] initWithPath:path error:errorOut];
}

- (id)initWithPath:(NSString *)path error:(NSError *__autoreleasing *)errorOut
{
    if ((self = [super init]))
    {
        _path = path;

        leveldb::Options options = [[self class] defaultCreateOptions];

        leveldb::Status status = leveldb::DB::Open(options, [_path UTF8String], &_db);

        if (!status.ok())
        {
            if (errorOut)
            {
                NSString *statusString = [[NSString alloc] initWithCString:status.ToString().c_str() encoding:NSUTF8StringEncoding];
                *errorOut = [NSError errorWithDomain:APLevelDBErrorDomain
                                                code:0
                                            userInfo:[NSDictionary dictionaryWithObjectsAndKeys:statusString, NSLocalizedDescriptionKey, nil]];
            }
            return nil;
        }

        _writeOptions.sync = false;
    }
    return self;
}

- (void)close {
    if (_db != NULL) {
        delete _db;
        _db = NULL;
    }
}

- (void)dealloc
{
    if (_db != NULL) {
        delete _db;
        _db = NULL;
    }
}

+ (leveldb::Options)defaultCreateOptions
{
    leveldb::Options options;
    options.create_if_missing = true;
    return options;
}

- (BOOL)setData:(NSData *)data forKey:(NSString *)key
{
    leveldb::Slice keySlice = SliceFromString(key);
    leveldb::Slice valueSlice = leveldb::Slice((const char *)[data bytes], (size_t)[data length]);
    leveldb::Status status = _db->Put(_writeOptions, keySlice, valueSlice);
    return (status.ok() == true);
}

- (BOOL)setString:(NSString *)str forKey:(NSString *)key
{
    // This could have been based on
    leveldb::Slice keySlice = SliceFromString(key);
    leveldb::Slice valueSlice = SliceFromString(str);
    leveldb::Status status = _db->Put(_writeOptions, keySlice, valueSlice);
    return (status.ok() == true);
}

- (NSData *)dataForKey:(NSString *)key
{
    leveldb::Slice keySlice = SliceFromString(key);
    std::string valueCPPString;
    leveldb::Status status = _db->Get(_readOptions, keySlice, &valueCPPString);

    if (!status.ok())
        return nil;
    else
        return [NSData dataWithBytes:valueCPPString.data() length:valueCPPString.size()];
}

- (NSString *)stringForKey:(NSString *)key
{
    leveldb::Slice keySlice = SliceFromString(key);
    std::string valueCPPString;
    leveldb::Status status = _db->Get(_readOptions, keySlice, &valueCPPString);

    // We assume (dangerously?) UTF-8 string encoding:
    if (!status.ok())
        return nil;
    else
        return [[NSString alloc] initWithBytes:valueCPPString.data() length:valueCPPString.size() encoding:NSUTF8StringEncoding];
}

- (BOOL)removeKey:(NSString *)key
{
    leveldb::Slice keySlice = SliceFromString(key);
    leveldb::Status status = _db->Delete(_writeOptions, keySlice);
    return (status.ok() == true);
}

- (NSArray *)allKeys
{
    NSMutableArray *keys = [NSMutableArray array];
    [self enumerateKeys:^(NSString *key, BOOL *stop) {
        [keys addObject:key];
    }];
    return keys;
}

- (void)enumerateKeysAndValuesAsStrings:(void (^)(NSString *key, NSString *value, BOOL *stop))block
{
    [self enumerateKeysWithPrefix:@"" asStrings:block];
}

- (void)enumerateKeysWithPrefix:(NSString *)prefixString asStrings:(void (^)(NSString *, NSString *, BOOL *))block
{
    @autoreleasepool {
        BOOL stop = NO;
        leveldb::Iterator* iter = _db->NewIterator(leveldb::ReadOptions());
        leveldb::Slice prefix = SliceFromString(prefixString);
        for (iter->Seek(prefix); iter->Valid(); iter->Next()) {
            leveldb::Slice key = iter->key(), value = iter->value();
            if (key.starts_with(prefix)) {
                NSString *k = StringFromSlice(key);
                NSString *v = [[NSString alloc] initWithBytes:value.data() length:value.size() encoding:NSUTF8StringEncoding];
                block(k, v, &stop);
                if (stop)
                    break;
            } else {
                break;
            }
        }

        delete iter;
    }
}

- (void)enumerateKeys:(void (^)(NSString *key, BOOL *stop))block
{
    [self enumerateKeysWithPrefix:@"" usingBlock:block];
}

- (void)enumerateKeysWithPrefix:(NSString *)prefixString usingBlock:(void (^)(NSString *key, BOOL *stop))block;
{
    @autoreleasepool {
        BOOL stop = NO;
        leveldb::Slice prefix = SliceFromString(prefixString);
        leveldb::Iterator* iter = _db->NewIterator(leveldb::ReadOptions());
        for (iter->Seek(prefix); iter->Valid(); iter->Next()) {
            leveldb::Slice key = iter->key();
            if (key.starts_with(prefix)) {
                NSString *k = StringFromSlice(key);
                block(k, &stop);
                if (stop)
                    break;
            } else {
                break;
            }
        }

        delete iter;
    }
}

- (void)enumerateKeysAndValuesAsData:(void (^)(NSString *key, NSData *data, BOOL *stop))block
{
    [self enumerateKeysWithPrefix:@"" asData:block];
}

- (void)enumerateKeysWithPrefix:(NSString *)prefixString asData:(void (^)(NSString *, NSData *, BOOL *))block
{
    @autoreleasepool {
        BOOL stop = NO;
        leveldb::Iterator* iter = _db->NewIterator(leveldb::ReadOptions());
        leveldb::Slice prefix = SliceFromString(prefixString);
        for (iter->Seek(prefix); iter->Valid(); iter->Next()) {
            leveldb::Slice key = iter->key(), value = iter->value();
            if (key.starts_with(prefix)) {
                NSString *k = StringFromSlice(key);
                NSData *data = [NSData dataWithBytes:value.data() length:value.size()];
                block(k, data, &stop);
                if (stop)
                    break;
            } else {
                break;
            }
        }

        delete iter;
    }
}

- (NSUInteger)exactSizeFrom:(NSString *)from to:(NSString *)to {
    NSUInteger size = 0;
    leveldb::Iterator* iter = _db->NewIterator(leveldb::ReadOptions());
    leveldb::Slice fromSlice = SliceFromString(from);
    leveldb::Slice toSlice = SliceFromString(to);
    iter->Seek(fromSlice);
    while (iter->Valid() && iter->key().compare(toSlice) <= 0) {
        size += iter->value().size();
        iter->Next();
    }
    delete iter;
    return size;
}


- (NSUInteger)approximateSizeFrom:(NSString *)from to:(NSString *)to {
    leveldb::Range ranges[1];
    leveldb::Slice fromSlice = SliceFromString(from);
    leveldb::Slice toSlice = SliceFromString(to);
    ranges[0] = leveldb::Range(fromSlice, toSlice);
    uint64_t sizes[1];
    _db->GetApproximateSizes(ranges, 1, sizes);
    return (NSUInteger)sizes[0];
}

#pragma mark - Subscripting Support

- (id)objectForKeyedSubscript:(id)key
{
    if (![key respondsToSelector: @selector(componentsSeparatedByString:)])
    {
        [NSException raise:NSInvalidArgumentException format:@"key must be an NSString"];
    }
    return [self stringForKey:key];
}
- (void)setObject:(id)thing forKeyedSubscript:(id<NSCopying>)key
{
    id idKey = (id) key;
    if (![idKey respondsToSelector: @selector(componentsSeparatedByString:)])
    {
        [NSException raise:NSInvalidArgumentException format:@"key must be NSString or NSData"];
    }

    if ([thing respondsToSelector:@selector(componentsSeparatedByString:)])
        [self setString:thing forKey:(NSString *)key];
    else if ([thing respondsToSelector:@selector(subdataWithRange:)])
        [self setData:thing forKey:(NSString *)key];
    else
        [NSException raise:NSInvalidArgumentException format:@"object must be NSString or NSData"];
}

#pragma mark - Atomic Updates

- (id<APLevelDBWriteBatch>)beginWriteBatch
{
    APLevelDBWriteBatch *batch = [[APLevelDBWriteBatch alloc] initWithLevelDB:self];
    return batch;
}

- (BOOL)commitWriteBatch:(id<APLevelDBWriteBatch>)theBatch
{
    if (!theBatch)
        return NO;

    APLevelDBWriteBatch *batch = theBatch;

    leveldb::Status status;
    status = _db->Write(_writeOptions, &batch->_batch);
    return (status.ok() == true);
}

@end


#pragma mark - APLevelDBIterator

@interface APLevelDBIterator () {
    leveldb::Iterator *_iter;
}

@property (nonatomic, strong) APLevelDB *levelDB;
@end



@implementation APLevelDBIterator

+ (id)iteratorWithLevelDB:(APLevelDB *)db
{
    APLevelDBIterator *iter = [[[self class] alloc] initWithLevelDB:db];
    return iter;
}

- (id)initWithLevelDB:(APLevelDB *)db
{
    if ((self = [super init]))
    {
        // Hold on to the database so it doesn't get deallocated before the iterator is deallocated
        self->_levelDB = db;
        _iter = db.db->NewIterator(leveldb::ReadOptions());
        _iter->SeekToFirst();
        if (!_iter->Valid())
            return nil;
    }
    return self;
}

- (id)init
{
    [NSException raise:@"BadInitializer" format:@"Use the designated initializer, -initWithLevelDB:, instead."];
    return nil;
}

- (void)dealloc
{
    self->_levelDB = nil;
    delete _iter;
    _iter = NULL;
}

- (BOOL)seekToKey:(NSString *)key
{
    leveldb::Slice target = SliceFromString(key);
    _iter->Seek(target);
    return _iter->Valid() == true;
}

- (void)seekToFirst
{
    _iter->SeekToFirst();
}

- (void)seekToLast
{
    _iter->SeekToLast();
}

- (NSString *)nextKey
{
    _iter->Next();
    return [self key];
}

- (NSString *)key
{
    if (_iter->Valid() == false)
        return nil;
    leveldb::Slice value = _iter->key();
    return StringFromSlice(value);
}

- (NSString *)valueAsString
{
    if (_iter->Valid() == false)
        return nil;
    leveldb::Slice value = _iter->value();
    return StringFromSlice(value);
}

- (NSData *)valueAsData
{
    if (_iter->Valid() == false)
        return nil;
    leveldb::Slice value = _iter->value();
    return [NSData dataWithBytes:value.data() length:value.size()];
}

@end



#pragma mark - APLevelDBWriteBatch

@implementation APLevelDBWriteBatch

- (id)initWithLevelDB:(APLevelDB *)levelDB {
    self = [super init];
    if (self != nil) {
        self->_levelDB = levelDB;
    }
    return self;
}

- (void)setData:(NSData *)data forKey:(NSString *)key
{
    leveldb::Slice keySlice = SliceFromString(key);
    leveldb::Slice valueSlice = leveldb::Slice((const char *)[data bytes], (size_t)[data length]);
    _batch.Put(keySlice, valueSlice);
}
- (void)setString:(NSString *)str forKey:(NSString *)key
{
    leveldb::Slice keySlice = SliceFromString(key);
    leveldb::Slice valueSlice = SliceFromString(str);
    _batch.Put(keySlice, valueSlice);
}

- (void)removeKey:(NSString *)key
{
    leveldb::Slice keySlice = SliceFromString(key);
    _batch.Delete(keySlice);
}

- (void)clear
{
    _batch.Clear();
}

- (BOOL)commit {
    return [self.levelDB commitWriteBatch:self];
}

@end

