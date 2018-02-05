#import "Firestore/third_party/Immutable/FSTImmutableSortedDictionary.h"

#import "Firestore/third_party/Immutable/FSTArraySortedDictionary.h"
#import "Firestore/Source/Util/FSTClasses.h"
#import "Firestore/third_party/Immutable/FSTTreeSortedDictionary.h"

NS_ASSUME_NONNULL_BEGIN

const int kSortedDictionaryArrayToRBTreeSizeThreshold = 25;

@implementation FSTImmutableSortedDictionary

+ (FSTImmutableSortedDictionary *)dictionaryWithComparator:(NSComparator)comparator {
  return [[FSTArraySortedDictionary alloc] initWithComparator:comparator];
}

+ (FSTImmutableSortedDictionary *)dictionaryWithDictionary:(NSDictionary *)dictionary
                                                comparator:(NSComparator)comparator {
  if (dictionary.count <= kSortedDictionaryArrayToRBTreeSizeThreshold) {
    return [FSTArraySortedDictionary dictionaryWithDictionary:dictionary comparator:comparator];
  } else {
    return [FSTTreeSortedDictionary dictionaryWithDictionary:dictionary comparator:comparator];
  }
}

- (FSTImmutableSortedDictionary *)dictionaryBySettingObject:(id)aValue forKey:(id)aKey {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (FSTImmutableSortedDictionary *)dictionaryByRemovingObjectForKey:(id)aKey {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (BOOL)isEqual:(id)object {
  if (![object isKindOfClass:[FSTImmutableSortedDictionary class]]) {
    return NO;
  }

  // TODO(klimt): We could make this more efficient if we put the comparison inside the
  // implementations and short-circuit if they share the same tree node, for instance.
  FSTImmutableSortedDictionary *other = (FSTImmutableSortedDictionary *)object;
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

- (nullable id)objectForKey:(id)key {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (id)objectForKeyedSubscript:(id)key {
  return [self objectForKey:key];
}

- (NSUInteger)indexOfKey:(id)key {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (BOOL)isEmpty {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (NSUInteger)count {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (id)minKey {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (id)maxKey {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(id, id, BOOL *))block {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (void)enumerateKeysAndObjectsReverse:(BOOL)reverse usingBlock:(void (^)(id, id, BOOL *))block {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (BOOL)containsKey:(id)key {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (NSEnumerator *)keyEnumerator {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (NSEnumerator *)keyEnumeratorFrom:(id)startKey {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (NSEnumerator *)keyEnumeratorFrom:(id)startKey to:(nullable id)endKey {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (NSEnumerator *)reverseKeyEnumerator {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (NSEnumerator *)reverseKeyEnumeratorFrom:(id)startKey {
  @throw FSTAbstractMethodException();  // NOLINT
}

@end

NS_ASSUME_NONNULL_END
