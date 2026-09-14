#import "FImmutableSortedDictionary.h"
#import "FArraySortedDictionary.h"
#import "FTreeSortedDictionary.h"

#define THROW_ABSTRACT_METHOD_EXCEPTION(sel) do { \
  @throw [NSException exceptionWithName:NSInternalInconsistencyException \
  reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(sel)] \
  userInfo:nil]; \
} while(0)

@implementation FImmutableSortedDictionary

+ (FImmutableSortedDictionary *)dictionaryWithComparator:(NSComparator)comparator
{
    return [[FArraySortedDictionary alloc] initWithComparator:comparator];
}

+ (FImmutableSortedDictionary *)fromDictionary:(NSDictionary *)dictionary withComparator:(NSComparator)comparator
{
    if (dictionary.count <= SORTED_DICTIONARY_ARRAY_TO_RB_TREE_SIZE_THRESHOLD) {
        return [FArraySortedDictionary fromDictionary:dictionary withComparator:comparator];
    } else {
        return [FTreeSortedDictionary fromDictionary:dictionary withComparator:comparator];
    }
}

- (FImmutableSortedDictionary *) insertKey:(id)aKey withValue:(id)aValue {
    THROW_ABSTRACT_METHOD_EXCEPTION(@selector(insertKey:withValue:));
}

- (FImmutableSortedDictionary *) removeKey:(id)aKey {
    THROW_ABSTRACT_METHOD_EXCEPTION(@selector(removeKey:));
}

- (id) get:(id) key {
    THROW_ABSTRACT_METHOD_EXCEPTION(@selector(get:));
}

- (id) getPredecessorKey:(id) key {
    THROW_ABSTRACT_METHOD_EXCEPTION(@selector(getPredecessorKey:));
}

- (BOOL) isEmpty {
    THROW_ABSTRACT_METHOD_EXCEPTION(@selector(isEmpty));
}

- (int) count {
    THROW_ABSTRACT_METHOD_EXCEPTION(@selector((count)));
}

- (id) minKey {
    THROW_ABSTRACT_METHOD_EXCEPTION(@selector(minKey));
}

- (id) maxKey {
    THROW_ABSTRACT_METHOD_EXCEPTION(@selector(maxKey));
}

- (void) enumerateKeysAndObjectsUsingBlock:(void (^)(id, id, BOOL *))block {
    THROW_ABSTRACT_METHOD_EXCEPTION(@selector(enumerateKeysAndObjectsUsingBlock:));
}

- (void) enumerateKeysAndObjectsReverse:(BOOL)reverse usingBlock:(void (^)(id, id, BOOL *))block {
    THROW_ABSTRACT_METHOD_EXCEPTION(@selector(enumerateKeysAndObjectsReverse:usingBlock:));
}

- (BOOL) contains:(id)key {
    THROW_ABSTRACT_METHOD_EXCEPTION(@selector(contains:));
}

- (NSEnumerator *) keyEnumerator {
    THROW_ABSTRACT_METHOD_EXCEPTION(@selector(keyEnumerator));
}

- (NSEnumerator *) keyEnumeratorFrom:(id)startKey {
    THROW_ABSTRACT_METHOD_EXCEPTION(@selector(keyEnumeratorFrom:));
}

- (NSEnumerator *) reverseKeyEnumerator {
    THROW_ABSTRACT_METHOD_EXCEPTION(@selector(reverseKeyEnumerator));
}

- (NSEnumerator *) reverseKeyEnumeratorFrom:(id)startKey {
    THROW_ABSTRACT_METHOD_EXCEPTION(@selector(reverseKeyEnumeratorFrom:));
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[FImmutableSortedDictionary class]]) {
        return NO;
    }
    FImmutableSortedDictionary *other = (FImmutableSortedDictionary *)object;
    if (self.count != other.count) {
        return NO;
    }
    __block BOOL isEqual = YES;
    [self enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        id otherValue = [other objectForKey:key];
        isEqual = isEqual && (value == otherValue || [value isEqual:otherValue]);
        *stop = !isEqual;
    }];
    return isEqual;
}

- (NSUInteger)hash {
    __block NSUInteger hash = 0;
    [self enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        hash = (hash * 31 + [key hash]) * 17 + [value hash];
    }];
    return hash;
}

- (NSString *)description {
    NSMutableString *str = [[NSMutableString alloc] init];
    __block BOOL first = YES;
    [str appendString:@"{ "];
    [self enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        if (!first) {
            [str appendString:@", "];
        }
        first = NO;
        [str appendString:[NSString stringWithFormat:@"%@: %@", key, value]];
    }];
    [str appendString:@" }"];
    return str;
}

#pragma mark -
#pragma mark Methods similar to NSMutableDictionary

- (FImmutableSortedDictionary *) setObject:(__unsafe_unretained id)anObject forKey:(__unsafe_unretained id)aKey {
    return [self insertKey:aKey withValue:anObject];
}

- (FImmutableSortedDictionary *) removeObjectForKey:(__unsafe_unretained id)aKey {
    return [self removeKey:aKey];
}

- (id) objectForKey:(__unsafe_unretained id)key {
    return [self get:key];
}

@end
