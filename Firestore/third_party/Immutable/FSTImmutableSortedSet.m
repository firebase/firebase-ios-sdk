#import "Firestore/third_party/Immutable/FSTImmutableSortedSet.h"

#import "Firestore/third_party/Immutable/FSTImmutableSortedDictionary.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTImmutableSortedSet ()
@property(nonatomic, strong) FSTImmutableSortedDictionary *dictionary;
@end

@implementation FSTImmutableSortedSet

+ (FSTImmutableSortedSet *)setWithComparator:(NSComparator)comparator {
  return [FSTImmutableSortedSet setWithKeysFromDictionary:@{} comparator:comparator];
}

+ (FSTImmutableSortedSet *)setWithKeysFromDictionary:(NSDictionary *)dictionary
                                          comparator:(NSComparator)comparator {
  FSTImmutableSortedDictionary *setDict =
      [FSTImmutableSortedDictionary dictionaryWithDictionary:dictionary comparator:comparator];
  return [[FSTImmutableSortedSet alloc] initWithDictionary:setDict];
}

// Designated initializer.
- (id)initWithDictionary:(FSTImmutableSortedDictionary *)dictionary {
  self = [super init];
  if (self != nil) {
    _dictionary = dictionary;
  }
  return self;
}

- (BOOL)isEqual:(id)object {
  if (![object isKindOfClass:[FSTImmutableSortedSet class]]) {
    return NO;
  }

  FSTImmutableSortedSet *other = (FSTImmutableSortedSet *)object;

  return [self.dictionary isEqual:other.dictionary];
}

- (NSUInteger)hash {
  return [self.dictionary hash];
}

- (BOOL)containsObject:(id)object {
  return [self.dictionary containsKey:object];
}

- (FSTImmutableSortedSet *)setByAddingObject:(id)object {
  FSTImmutableSortedDictionary *newDictionary =
      [self.dictionary dictionaryBySettingObject:[NSNull null] forKey:object];
  if (newDictionary != self.dictionary) {
    return [[FSTImmutableSortedSet alloc] initWithDictionary:newDictionary];
  } else {
    return self;
  }
}

- (FSTImmutableSortedSet *)setByRemovingObject:(id)object {
  FSTImmutableSortedDictionary *newDictionary =
      [self.dictionary dictionaryByRemovingObjectForKey:object];
  if (newDictionary != self.dictionary) {
    return [[FSTImmutableSortedSet alloc] initWithDictionary:newDictionary];
  } else {
    return self;
  }
}

- (id)firstObject {
  return [self.dictionary minKey];
}

- (id)lastObject {
  return [self.dictionary maxKey];
}

- (NSUInteger)indexOfObject:(id)object {
  return [self.dictionary indexOfKey:object];
}

- (NSUInteger)count {
  return [self.dictionary count];
}

- (BOOL)isEmpty {
  return [self.dictionary isEmpty];
}

- (void)enumerateObjectsUsingBlock:(void (^)(id, BOOL *))block {
  [self enumerateObjectsReverse:NO usingBlock:block];
}

- (void)enumerateObjectsFrom:(id)start to:(_Nullable id)end usingBlock:(void (^)(id, BOOL *))block {
  NSEnumerator *enumerator = [self.dictionary keyEnumeratorFrom:start to:end];
  id item = [enumerator nextObject];
  while (item) {
    BOOL stop = NO;
    block(item, &stop);
    if (stop) {
      return;
    }
    item = [enumerator nextObject];
  }
}

- (void)enumerateObjectsReverse:(BOOL)reverse usingBlock:(void (^)(id, BOOL *))block {
  [self.dictionary enumerateKeysAndObjectsReverse:reverse
                                       usingBlock:^(id key, id value, BOOL *stop) {
                                         block(key, stop);
                                       }];
}

- (NSEnumerator *)objectEnumerator {
  return [self.dictionary keyEnumerator];
}

- (NSEnumerator *)objectEnumeratorFrom:(id)startKey {
  return [self.dictionary keyEnumeratorFrom:startKey];
}

- (NSString *)description {
  NSMutableString *str = [[NSMutableString alloc] init];
  __block BOOL first = YES;
  [str appendString:@"FSTImmutableSortedSet ( "];
  [self enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
    if (!first) {
      [str appendString:@", "];
    }
    first = NO;
    [str appendString:[NSString stringWithFormat:@"%@", obj]];
  }];
  [str appendString:@" )"];
  return str;
}

@end

NS_ASSUME_NONNULL_END
