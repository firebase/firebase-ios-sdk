#import "Firestore/third_party/Immutable/FSTTreeSortedDictionaryEnumerator.h"

NS_ASSUME_NONNULL_BEGIN

// clang-format off
// For some reason, clang-format messes this line up...
@interface FSTTreeSortedDictionaryEnumerator<KeyType, ValueType> ()
/** The dictionary being enumerated. */
@property(nonatomic, strong) FSTTreeSortedDictionary<KeyType, ValueType> *immutableSortedDictionary;
/** The stack of tree nodes above the current node that will need to be revisited later. */
@property(nonatomic, strong) NSMutableArray<id<FSTLLRBNode>> *stack;
/** The direction of the traversal. YES=Descending. NO=Ascending. */
@property(nonatomic, assign) BOOL isReverse;
/** If set, the enumerator should stop at this key and not return it. */
@property(nonatomic, strong, nullable) id endKey;
@end
// clang-format on

@implementation FSTTreeSortedDictionaryEnumerator

- (instancetype)initWithImmutableSortedDictionary:(FSTTreeSortedDictionary *)aDict
                                         startKey:(id _Nullable)startKey
                                           endKey:(id _Nullable)endKey
                                        isReverse:(BOOL)reverse {
  self = [super init];
  if (self) {
    _immutableSortedDictionary = aDict;
    _stack = [[NSMutableArray alloc] init];
    _isReverse = reverse;
    _endKey = endKey;

    NSComparator comparator = aDict.comparator;
    id<FSTLLRBNode> node = aDict.root;

    NSComparisonResult comparedToStart;
    NSComparisonResult comparedToEnd;
    while (![node isEmpty]) {
      comparedToStart = NSOrderedDescending;
      if (startKey) {
        comparedToStart = comparator(node.key, startKey);
        if (reverse) {
          comparedToStart *= -1;
        }
      }
      comparedToEnd = NSOrderedAscending;
      if (endKey) {
        comparedToEnd = comparator(node.key, endKey);
        if (reverse) {
          comparedToEnd *= -1;
        }
      }

      if (comparedToStart == NSOrderedAscending) {
        // This node is less than our start key. Ignore it.
        if (reverse) {
          node = node.left;
        } else {
          node = node.right;
        }
      } else if (comparedToStart == NSOrderedSame) {
        // This node is exactly equal to our start key. If it's less than the end key, push it on
        // the stack, but stop iterating.
        if (comparedToEnd == NSOrderedAscending) {
          [_stack addObject:node];
        }
        break;
      } else {
        // This node is greater than our start key. If it's less than our end key, add it to the
        // stack and move on to the next one.
        if (comparedToEnd == NSOrderedAscending) {
          [_stack addObject:node];
        }
        if (reverse) {
          node = node.right;
        } else {
          node = node.left;
        }
      }
    }
  }
  return self;
}

- (nullable id)nextObject {
  if ([self.stack count] == 0) {
    return nil;
  }

  id<FSTLLRBNode> node = [self.stack lastObject];
  [self.stack removeLastObject];
  id result = node.key;
  NSComparator comparator = self.immutableSortedDictionary.comparator;

  node = self.isReverse ? node.left : node.right;
  while (![node isEmpty]) {
    NSComparisonResult comparedToEnd = NSOrderedAscending;
    if (self.endKey) {
      comparedToEnd = comparator(node.key, self.endKey);
      if (self.isReverse) {
        comparedToEnd *= -1;
      }
    }
    if (comparedToEnd == NSOrderedAscending) {
      [self.stack addObject:node];
    }
    node = self.isReverse ? node.right : node.left;
  }

  return result;
}

@end

NS_ASSUME_NONNULL_END
