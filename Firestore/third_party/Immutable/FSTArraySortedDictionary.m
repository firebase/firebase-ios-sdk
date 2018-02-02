#import "Firestore/third_party/Immutable/FSTArraySortedDictionary.h"

#import "Firestore/third_party/Immutable/FSTArraySortedDictionaryEnumerator.h"
#import "Firestore/Source/Util/FSTAssert.h"
#import "Firestore/third_party/Immutable/FSTTreeSortedDictionary.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTArraySortedDictionary ()
@property(nonatomic, copy, readwrite) NSComparator comparator;
@property(nonatomic, strong) NSArray<id> *keys;
@property(nonatomic, strong) NSArray<id> *values;
@end

@implementation FSTArraySortedDictionary

+ (FSTArraySortedDictionary *)dictionaryWithDictionary:(NSDictionary *)dictionary
                                            comparator:(NSComparator)comparator {
  NSMutableArray *keys = [NSMutableArray arrayWithCapacity:dictionary.count];
  [dictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
    [keys addObject:key];
  }];
  [keys sortUsingComparator:comparator];

  [keys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
    if (idx > 0) {
      if (comparator(keys[idx - 1], obj) != NSOrderedAscending) {
        [NSException raise:NSInvalidArgumentException
                    format:
                        @"Can't create FSTImmutableSortedDictionary with keys "
                        @"with same ordering!"];
      }
    }
  }];

  NSMutableArray *values = [NSMutableArray arrayWithCapacity:keys.count];
  NSInteger pos = 0;
  for (id key in keys) {
    values[pos++] = dictionary[key];
  }
  FSTAssert(values.count == keys.count, @"We added as many keys as values");
  return [[FSTArraySortedDictionary alloc] initWithComparator:comparator keys:keys values:values];
}

- (id)initWithComparator:(NSComparator)comparator {
  return [self initWithComparator:comparator keys:[NSArray array] values:[NSArray array]];
}

// Designated initializer.
- (id)initWithComparator:(NSComparator)comparator keys:(NSArray *)keys values:(NSArray *)values {
  self = [super init];
  if (self != nil) {
    FSTAssert(keys.count == values.count, @"keys and values must have the same count");
    _comparator = comparator;
    _keys = keys;
    _values = values;
  }
  return self;
}

/** Returns the index of the first position where array[position] >= key.  */
- (int)findInsertPositionForKey:(id)key {
  int newPos = 0;
  while (newPos < self.keys.count && self.comparator(self.keys[newPos], key) < NSOrderedSame) {
    newPos++;
  }
  return newPos;
}

- (NSInteger)findKey:(id)key {
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

- (FSTImmutableSortedDictionary *)dictionaryBySettingObject:(id)value forKey:(id)key {
  NSInteger pos = [self findKey:key];

  if (pos == NSNotFound) {
    /*
     * If we're above the threshold we want to convert it to a tree backed implementation to not
     * have degrading performance
     */
    if (self.count >= kSortedDictionaryArrayToRBTreeSizeThreshold) {
      NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:self.count];
      for (NSInteger i = 0; i < self.keys.count; i++) {
        dict[self.keys[i]] = self.values[i];
      }
      dict[key] = value;
      return [FSTTreeSortedDictionary dictionaryWithDictionary:dict comparator:self.comparator];
    } else {
      NSMutableArray *newKeys = [NSMutableArray arrayWithArray:self.keys];
      NSMutableArray *newValues = [NSMutableArray arrayWithArray:self.values];
      NSInteger newPos = [self findInsertPositionForKey:key];
      [newKeys insertObject:key atIndex:newPos];
      [newValues insertObject:value atIndex:newPos];
      return [[FSTArraySortedDictionary alloc] initWithComparator:self.comparator
                                                             keys:newKeys
                                                           values:newValues];
    }
  } else {
    NSMutableArray *newKeys = [NSMutableArray arrayWithArray:self.keys];
    NSMutableArray *newValues = [NSMutableArray arrayWithArray:self.values];
    newKeys[pos] = key;
    newValues[pos] = value;
    return [[FSTArraySortedDictionary alloc] initWithComparator:self.comparator
                                                           keys:newKeys
                                                         values:newValues];
  }
}

- (FSTImmutableSortedDictionary *)dictionaryByRemovingObjectForKey:(id)key {
  NSInteger pos = [self findKey:key];
  if (pos == NSNotFound) {
    return self;
  } else {
    NSMutableArray *newKeys = [NSMutableArray arrayWithArray:self.keys];
    NSMutableArray *newValues = [NSMutableArray arrayWithArray:self.values];
    [newKeys removeObjectAtIndex:pos];
    [newValues removeObjectAtIndex:pos];
    return [[FSTArraySortedDictionary alloc] initWithComparator:self.comparator
                                                           keys:newKeys
                                                         values:newValues];
  }
}

- (nullable id)objectForKey:(id)key {
  NSInteger pos = [self findKey:key];
  if (pos == NSNotFound) {
    return nil;
  } else {
    return self.values[pos];
  }
}

- (NSUInteger)indexOfKey:(id)key {
  return [self findKey:key];
}

- (BOOL)isEmpty {
  return self.keys.count == 0;
}

- (NSUInteger)count {
  return self.keys.count;
}

- (id)minKey {
  return [self.keys firstObject];
}

- (id)maxKey {
  return [self.keys lastObject];
}

- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(id, id, BOOL *))block {
  [self enumerateKeysAndObjectsReverse:NO usingBlock:block];
}

- (void)enumerateKeysAndObjectsReverse:(BOOL)reverse usingBlock:(void (^)(id, id, BOOL *))block {
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

- (BOOL)containsKey:(id)key {
  return [self findKey:key] != NSNotFound;
}

- (NSEnumerator *)keyEnumerator {
  return [self.keys objectEnumerator];
}

- (NSEnumerator *)keyEnumeratorFrom:(id)startKey {
  return [self keyEnumeratorFrom:startKey to:nil];
}

- (NSEnumerator *)keyEnumeratorFrom:(id)startKey to:(nullable id)endKey {
  int start = [self findInsertPositionForKey:startKey];
  int end = (int)self.count;
  if (endKey) {
    end = [self findInsertPositionForKey:endKey];
  }
  return [[FSTArraySortedDictionaryEnumerator alloc] initWithKeys:self.keys
                                                         startPos:start
                                                           endPos:end
                                                        isReverse:NO];
}

- (NSEnumerator *)reverseKeyEnumerator {
  return [self.keys reverseObjectEnumerator];
}

- (NSEnumerator *)reverseKeyEnumeratorFrom:(id)startKey {
  int startPos = [self findInsertPositionForKey:startKey];
  // if there's no exact match, findKeyOrInsertPosition will return the index *after* the closest
  // match, but since this is a reverse iterator, we want to start just *before* the closest match.
  if (startPos >= self.keys.count ||
      self.comparator(self.keys[startPos], startKey) != NSOrderedSame) {
    startPos -= 1;
  }
  return [[FSTArraySortedDictionaryEnumerator alloc] initWithKeys:self.keys
                                                         startPos:startPos
                                                           endPos:-1
                                                        isReverse:YES];
}

@end

NS_ASSUME_NONNULL_END
