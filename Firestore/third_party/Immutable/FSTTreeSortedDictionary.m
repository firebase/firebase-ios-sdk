#import "Firestore/third_party/Immutable/FSTTreeSortedDictionary.h"

#import "Firestore/third_party/Immutable/FSTLLRBEmptyNode.h"
#import "Firestore/third_party/Immutable/FSTLLRBValueNode.h"
#import "Firestore/third_party/Immutable/FSTTreeSortedDictionaryEnumerator.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTTreeSortedDictionary ()

- (FSTTreeSortedDictionary *)dictionaryBySettingObject:(id)aValue forKey:(id)aKey;

@property(nonatomic, strong) id<FSTLLRBNode> root;
@property(nonatomic, copy, readwrite) NSComparator comparator;
@end

@implementation FSTTreeSortedDictionary

+ (FSTTreeSortedDictionary *)dictionaryWithDictionary:(NSDictionary *)dictionary
                                           comparator:(NSComparator)comparator {
  __block FSTTreeSortedDictionary *dict =
      [[FSTTreeSortedDictionary alloc] initWithComparator:comparator];
  [dictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
    dict = [dict dictionaryBySettingObject:obj forKey:key];
  }];
  return dict;
}

- (id)initWithComparator:(NSComparator)aComparator {
  return [self initWithComparator:aComparator withRoot:[FSTLLRBEmptyNode emptyNode]];
}

// Designated initializer.
- (id)initWithComparator:(NSComparator)aComparator withRoot:(id<FSTLLRBNode>)aRoot {
  self = [super init];
  if (self) {
    self.root = aRoot;
    self.comparator = aComparator;
  }
  return self;
}

/**
 * Returns a copy of the map, with the specified key/value added or replaced.
 */
- (FSTTreeSortedDictionary *)dictionaryBySettingObject:(id)aValue forKey:(id)aKey {
  return [[FSTTreeSortedDictionary alloc]
      initWithComparator:self.comparator
                withRoot:[[self.root insertKey:aKey forValue:aValue withComparator:self.comparator]
                              copyWith:nil
                             withValue:nil
                             withColor:FSTLLRBColorBlack
                              withLeft:nil
                             withRight:nil]];
}

- (FSTTreeSortedDictionary *)dictionaryByRemovingObjectForKey:(id)aKey {
  // Remove is somewhat expensive even if the key doesn't exist (the tree does rebalancing and
  // stuff).  So avoid it.
  if (![self containsKey:aKey]) {
    return self;
  } else {
    return [[FSTTreeSortedDictionary alloc]
        initWithComparator:self.comparator
                  withRoot:[[self.root remove:aKey withComparator:self.comparator]
                                copyWith:nil
                               withValue:nil
                               withColor:FSTLLRBColorBlack
                                withLeft:nil
                               withRight:nil]];
  }
}

- (nullable id)objectForKey:(id)key {
  NSComparisonResult cmp;
  id<FSTLLRBNode> node = self.root;
  while (![node isEmpty]) {
    cmp = self.comparator(key, node.key);
    if (cmp == NSOrderedSame) {
      return node.value;
    } else if (cmp == NSOrderedAscending) {
      node = node.left;
    } else {
      node = node.right;
    }
  }
  return nil;
}

- (NSUInteger)indexOfKey:(id)key {
  NSUInteger prunedNodes = 0;
  id<FSTLLRBNode> node = self.root;
  while (![node isEmpty]) {
    NSComparisonResult cmp = self.comparator(key, node.key);
    if (cmp == NSOrderedSame) {
      return prunedNodes + node.left.count;
    } else if (cmp == NSOrderedAscending) {
      node = node.left;
    } else if (cmp == NSOrderedDescending) {
      prunedNodes += node.left.count + 1;
      node = node.right;
    }
  }
  return NSNotFound;
}

- (BOOL)isEmpty {
  return [self.root isEmpty];
}

- (NSUInteger)count {
  return [self.root count];
}

- (id)minKey {
  return [self.root minKey];
}

- (id)maxKey {
  return [self.root maxKey];
}

- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(id, id, BOOL *))block {
  [self enumerateKeysAndObjectsReverse:NO usingBlock:block];
}

- (void)enumerateKeysAndObjectsReverse:(BOOL)reverse usingBlock:(void (^)(id, id, BOOL *))block {
  if (reverse) {
    __block BOOL stop = NO;
    [self.root reverseTraversal:^BOOL(id key, id value) {
      block(key, value, &stop);
      return stop;
    }];
  } else {
    __block BOOL stop = NO;
    [self.root inorderTraversal:^BOOL(id key, id value) {
      block(key, value, &stop);
      return stop;
    }];
  }
}

- (BOOL)containsKey:(id)key {
  return ([self objectForKey:key] != nil);
}

- (NSEnumerator *)keyEnumerator {
  return [[FSTTreeSortedDictionaryEnumerator alloc] initWithImmutableSortedDictionary:self
                                                                             startKey:nil
                                                                               endKey:nil
                                                                            isReverse:NO];
}

- (NSEnumerator *)keyEnumeratorFrom:(id)startKey {
  return [[FSTTreeSortedDictionaryEnumerator alloc] initWithImmutableSortedDictionary:self
                                                                             startKey:startKey
                                                                               endKey:nil
                                                                            isReverse:NO];
}

- (NSEnumerator *)keyEnumeratorFrom:(id)startKey to:(nullable id)endKey {
  return [[FSTTreeSortedDictionaryEnumerator alloc] initWithImmutableSortedDictionary:self
                                                                             startKey:startKey
                                                                               endKey:endKey
                                                                            isReverse:NO];
}

- (NSEnumerator *)reverseKeyEnumerator {
  return [[FSTTreeSortedDictionaryEnumerator alloc] initWithImmutableSortedDictionary:self
                                                                             startKey:nil
                                                                               endKey:nil
                                                                            isReverse:YES];
}

- (NSEnumerator *)reverseKeyEnumeratorFrom:(id)startKey {
  return [[FSTTreeSortedDictionaryEnumerator alloc] initWithImmutableSortedDictionary:self
                                                                             startKey:startKey
                                                                               endKey:nil
                                                                            isReverse:YES];
}

#pragma mark -
#pragma mark Tree Builder

// Code to efficiently build a red black tree.

typedef struct {
  unsigned int bits;
  unsigned short count;
  unsigned short current;
} Base12List;

unsigned int LogBase2(unsigned int num) {
  return (unsigned int)(log(num) / log(2));
}

/**
 * Works like an iterator, so it moves to the next bit. Do not call more than list->count times.
 * @return whether or not the next bit is a 1 in base {1,2}.
 */
BOOL Base12ListNext(Base12List *list) {
  BOOL result = !(list->bits & (0x1 << list->current));
  list->current--;
  return result;
}

static inline unsigned BitMask(int x) {
  return (x >= sizeof(unsigned) * CHAR_BIT) ? (unsigned)-1 : (1U << x) - 1;
}

/**
 * We represent the base{1,2} number as the combination of a binary number and a number of bits that
 * we care about. We iterate backwards, from most significant bit to least, to build up the llrb
 * nodes. 0 base 2 => 1 base {1,2}, 1 base 2 => 2 base {1,2}
 */
Base12List *NewBase12List(unsigned int length) {
  size_t sz = sizeof(Base12List);
  Base12List *list = calloc(1, sz);
  // Calculate the number of bits that we care about
  list->count = (unsigned short)LogBase2(length + 1);
  unsigned int mask = BitMask(list->count);
  list->bits = (length + 1) & mask;
  list->current = list->count - 1;
  return list;
}

void FreeBase12List(Base12List *list) {
  free(list);
}

+ (nullable id<FSTLLRBNode>)buildBalancedTree:(NSArray *)keys
                                   dictionary:(NSDictionary *)dictionary
                           subArrayStartIndex:(NSUInteger)startIndex
                                       length:(NSUInteger)length {
  length = MIN(keys.count - startIndex, length);  // Bound length by the actual length of the array
  if (length == 0) {
    return nil;
  } else if (length == 1) {
    id key = keys[startIndex];
    return [[FSTLLRBValueNode alloc] initWithKey:key
                                       withValue:dictionary[key]
                                       withColor:FSTLLRBColorBlack
                                        withLeft:nil
                                       withRight:nil];
  } else {
    NSUInteger middle = length / 2;
    id<FSTLLRBNode> left = [FSTTreeSortedDictionary buildBalancedTree:keys
                                                           dictionary:dictionary
                                                   subArrayStartIndex:startIndex
                                                               length:middle];
    id<FSTLLRBNode> right = [FSTTreeSortedDictionary buildBalancedTree:keys
                                                            dictionary:dictionary
                                                    subArrayStartIndex:(startIndex + middle + 1)
                                                                length:middle];
    id key = keys[startIndex + middle];
    return [[FSTLLRBValueNode alloc] initWithKey:key
                                       withValue:dictionary[key]
                                       withColor:FSTLLRBColorBlack
                                        withLeft:left
                                       withRight:right];
  }
}

+ (nullable id<FSTLLRBNode>)rootFrom12List:(Base12List *)base12List
                                   keyList:(NSArray *)keyList
                                dictionary:(NSDictionary *)dictionary {
  __block FSTLLRBValueNode *root = nil;
  __block FSTLLRBValueNode *node = nil;
  __block NSUInteger index = keyList.count;

  void (^buildPennant)(FSTLLRBColor, NSUInteger) = ^(FSTLLRBColor color, NSUInteger chunkSize) {
    NSUInteger startIndex = index - chunkSize + 1;
    index -= chunkSize;
    id key = keyList[index];
    FSTLLRBValueNode *childTree = [self buildBalancedTree:keyList
                                               dictionary:dictionary
                                       subArrayStartIndex:startIndex
                                                   length:(chunkSize - 1)];
    FSTLLRBValueNode *pennant = [[FSTLLRBValueNode alloc] initWithKey:key
                                                            withValue:dictionary[key]
                                                            withColor:color
                                                             withLeft:nil
                                                            withRight:childTree];
    if (node) {
      // This is the only place this property is set.
      node.left = pennant;
      node = pennant;
    } else {
      root = pennant;
      node = pennant;
    }
  };

  for (int i = 0; i < base12List->count; ++i) {
    BOOL isOne = Base12ListNext(base12List);
    NSUInteger chunkSize = (NSUInteger)pow(2.0, base12List->count - (i + 1));
    if (isOne) {
      buildPennant(FSTLLRBColorBlack, chunkSize);
    } else {
      buildPennant(FSTLLRBColorBlack, chunkSize);
      buildPennant(FSTLLRBColorRed, chunkSize);
    }
  }
  return root;
}

/**
 * Uses the algorithm linked here:
 * http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.46.1458
 */
+ (FSTImmutableSortedDictionary *)fromDictionary:(NSDictionary *)dictionary
                                  withComparator:(NSComparator)comparator {
  // Steps:
  // 0. Sort the array
  // 1. Calculate the 1-2 number
  // 2. Build From 1-2 number
  //   0. for each digit in 1-2 number
  //     0. calculate chunk size
  //     1. build 1 or 2 pennants of that size
  //     2. attach pennants and update node pointer
  //   1. return root
  NSMutableArray *sortedKeyList = [NSMutableArray arrayWithCapacity:dictionary.count];
  [dictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
    [sortedKeyList addObject:key];
  }];
  [sortedKeyList sortUsingComparator:comparator];

  [sortedKeyList enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
    if (idx > 0) {
      if (comparator(sortedKeyList[idx - 1], obj) != NSOrderedAscending) {
        [NSException raise:NSInvalidArgumentException
                    format:
                        @"Can't create FSTImmutableSortedDictionary "
                        @"with keys with same ordering!"];
      }
    }
  }];

  Base12List *list = NewBase12List((unsigned int)sortedKeyList.count);
  id<FSTLLRBNode> root = [self rootFrom12List:list keyList:sortedKeyList dictionary:dictionary];
  FreeBase12List(list);

  if (root != nil) {
    return [[FSTTreeSortedDictionary alloc] initWithComparator:comparator withRoot:root];
  } else {
    return [[FSTTreeSortedDictionary alloc] initWithComparator:comparator];
  }
}

@end

NS_ASSUME_NONNULL_END
