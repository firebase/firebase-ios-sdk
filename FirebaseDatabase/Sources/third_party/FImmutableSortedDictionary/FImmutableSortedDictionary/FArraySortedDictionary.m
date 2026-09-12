#import "FArraySortedDictionary.h"
#import "FTreeSortedDictionary.h"

@interface FArraySortedDictionaryEnumerator : NSEnumerator

- (id)initWithKeys:(NSArray *)keys startPos:(NSInteger)pos isReverse:(BOOL)reverse;
- (id)nextObject;

@property (nonatomic) NSInteger pos;
@property (nonatomic) BOOL reverse;
@property (nonatomic, strong) NSArray *keys;

@end

@implementation FArraySortedDictionaryEnumerator

- (id)initWithKeys:(NSArray *)keys startPos:(NSInteger)pos isReverse:(BOOL)reverse
{
    self = [super init];
    if (self != nil) {
        self->_pos = pos;
        self->_reverse = reverse;
        self->_keys = keys;
    }
    return self;
}

- (id)nextObject
{
    NSInteger pos = self->_pos;
    if (pos >= 0 && pos < self.keys.count) {
        if (self.reverse) {
            self->_pos--;
        } else {
            self->_pos++;
        }
        return self.keys[pos];
    } else {
        return nil;
    }
}

@end

@interface FArraySortedDictionary ()

- (id)initWithComparator:(NSComparator)comparator;

@property (nonatomic, copy, readwrite) NSComparator comparator;
@property (nonatomic, strong) NSArray *keys;
@property (nonatomic, strong) NSArray *values;

@end

@implementation FArraySortedDictionary

+ (FArraySortedDictionary *)fromDictionary:(NSDictionary *)dictionary withComparator:(NSComparator)comparator
{
    NSMutableArray *keys = [NSMutableArray arrayWithCapacity:dictionary.count];
    [dictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [keys addObject:key];
    }];
    [keys sortUsingComparator:comparator];

    [keys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if (idx > 0) {
            if (comparator(keys[idx - 1], obj) != NSOrderedAscending) {
                [NSException raise:NSInvalidArgumentException format:@"Can't create FImmutableSortedDictionary with keys with same ordering!"];
            }
        }
    }];

    NSMutableArray *values = [NSMutableArray arrayWithCapacity:keys.count];
    NSInteger pos = 0;
    for (id key in keys) {
        values[pos++] = dictionary[key];
    }
    NSAssert(values.count == keys.count, @"We added as many keys as values");
    return [[FArraySortedDictionary alloc] initWithComparator:comparator keys:keys values:values];
}

- (id)initWithComparator:(NSComparator)comparator
{
    self = [super init];
    if (self != nil) {
        self->_comparator = comparator;
        self->_keys = [NSArray array];
        self->_values = [NSArray array];
    }
    return self;
}

- (id)initWithComparator:(NSComparator)comparator keys:(NSArray *)keys values:(NSArray *)values
{
    self = [super init];
    if (self != nil) {
        self->_comparator = comparator;
        self->_keys = keys;
        self->_values = values;
    }
    return self;
}

- (NSInteger) findInsertPositionForKey:(id)key
{
    NSInteger newPos = 0;
    while (newPos < self.keys.count && self.comparator(self.keys[newPos], key) < NSOrderedSame) {
        newPos++;
    }
    return newPos;
}

- (NSInteger) findKey:(id)key
{
    if (key == nil) {
        return NSNotFound;
    }
    for (NSInteger pos = 0; pos < self.keys.count; pos++) {
        NSComparisonResult result = self.comparator(key, self.keys[pos]);
        if (result == NSOrderedSame) {
            return pos;
        } else if (result == NSOrderedAscending) {
            return NSNotFound;
        }
    }
    return NSNotFound;
}

- (FImmutableSortedDictionary *) insertKey:(id)key withValue:(id)value
{
    NSInteger pos = [self findKey:key];

    if (pos == NSNotFound) {
        /*
         * If we're above the threshold we want to convert it to a tree backed implementation to not have
         * degrading performance
         */
        if (self.count >= SORTED_DICTIONARY_ARRAY_TO_RB_TREE_SIZE_THRESHOLD) {
            NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:self.count];
            for (NSInteger i = 0; i < self.keys.count; i++) {
                dict[self.keys[i]] = self.values[i];
            }
            dict[key] = value;
            return [FTreeSortedDictionary fromDictionary:dict withComparator:self.comparator];
        } else {
            NSMutableArray *newKeys = [NSMutableArray arrayWithArray:self.keys];
            NSMutableArray *newValues = [NSMutableArray arrayWithArray:self.values];
            NSInteger newPos = [self findInsertPositionForKey:key];
            [newKeys insertObject:key atIndex:newPos];
            [newValues insertObject:value atIndex:newPos];
            return [[FArraySortedDictionary alloc] initWithComparator:self.comparator keys:newKeys values:newValues];
        }
    } else {
        NSMutableArray *newKeys = [NSMutableArray arrayWithArray:self.keys];
        NSMutableArray *newValues = [NSMutableArray arrayWithArray:self.values];
        newKeys[pos] = key;
        newValues[pos] = value;
        return [[FArraySortedDictionary alloc] initWithComparator:self.comparator keys:newKeys values:newValues];
    }
}

- (FImmutableSortedDictionary *) removeKey:(id)key
{
    NSInteger pos = [self findKey:key];
    if (pos == NSNotFound) {
        return self;
    } else {
        NSMutableArray *newKeys = [NSMutableArray arrayWithArray:self.keys];
        NSMutableArray *newValues = [NSMutableArray arrayWithArray:self.values];
        [newKeys removeObjectAtIndex:pos];
        [newValues removeObjectAtIndex:pos];
        return [[FArraySortedDictionary alloc] initWithComparator:self.comparator keys:newKeys values:newValues];
    }
}

- (id) get:(id)key
{
    NSInteger pos = [self findKey:key];
    if (pos == NSNotFound) {
        return nil;
    } else {
        return self.values[pos];
    }
}

- (id) getPredecessorKey:(id) key {
    NSInteger pos = [self findKey:key];
    if (pos == NSNotFound) {
        [NSException raise:NSInternalInconsistencyException format:@"Can't get predecessor key for non-existent key"];
        return nil;
    } else if (pos == 0) {
        return nil;
    } else {
        return self.keys[pos - 1];
    }
}

- (BOOL) isEmpty {
    return self.keys.count == 0;
}

- (int) count
{
    return (int)self.keys.count;
}

- (id) minKey
{
    return [self.keys firstObject];
}

- (id) maxKey
{
    return [self.keys lastObject];
}

- (void) enumerateKeysAndObjectsUsingBlock:(void (^)(id, id, BOOL *))block
{
    [self enumerateKeysAndObjectsReverse:NO usingBlock:block];
}

- (void) enumerateKeysAndObjectsReverse:(BOOL)reverse usingBlock:(void (^)(id, id, BOOL *))block
{
    if (reverse) {
        BOOL stop = NO;
        for (NSInteger i = self.keys.count - 1; i >= 0; i--) {
            block(self.keys[i], self.values[i], &stop);
            if (stop) return;
        }
    } else {
        BOOL stop = NO;
        for (NSInteger i = 0; i < self.keys.count; i++) {
            block(self.keys[i], self.values[i], &stop);
            if (stop) return;
        }
    }
}

- (BOOL) contains:(id)key {
    return [self findKey:key] != NSNotFound;
}

- (NSEnumerator *) keyEnumerator {
    return [self.keys objectEnumerator];
}

- (NSEnumerator *) keyEnumeratorFrom:(id)startKey {
    NSInteger startPos = [self findInsertPositionForKey:startKey];
    return [[FArraySortedDictionaryEnumerator alloc] initWithKeys:self.keys startPos:startPos isReverse:NO];
}

- (NSEnumerator *) reverseKeyEnumerator {
    return [self.keys reverseObjectEnumerator];
}

- (NSEnumerator *) reverseKeyEnumeratorFrom:(id)startKey {
    NSInteger startPos = [self findInsertPositionForKey:startKey];
    // if there's no exact match, findKeyOrInsertPosition will return the index *after* the closest match, but
    // since this is a reverse iterator, we want to start just *before* the closest match.
    if (startPos >= self.keys.count || self.comparator(self.keys[startPos], startKey) != NSOrderedSame) {
        startPos -= 1;
    }
    return [[FArraySortedDictionaryEnumerator alloc] initWithKeys:self.keys startPos:startPos isReverse:YES];
}

@end
