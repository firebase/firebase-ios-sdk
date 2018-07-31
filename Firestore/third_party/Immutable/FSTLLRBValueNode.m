#import "Firestore/third_party/Immutable/FSTLLRBValueNode.h"

#import "Firestore/third_party/Immutable/FSTLLRBEmptyNode.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTLLRBValueNode ()
@property(nonatomic, assign) FSTLLRBColor color;
@property(nonatomic, assign) NSUInteger count;
@property(nonatomic, strong) id key;
@property(nonatomic, strong) id value;
@property(nonatomic, strong) id<FSTLLRBNode> right;
@end

@implementation FSTLLRBValueNode

- (NSString *)colorDescription {
  NSString *color = @"unspecified";
  if (self.color == FSTLLRBColorRed) {
    color = @"red";
  } else if (self.color == FSTLLRBColorBlack) {
    color = @"black";
  }
  return color;
}

- (NSString *)description {
  NSString *color = self.colorDescription;
  return [NSString stringWithFormat:@"[key=%@ val=%@ color=%@]", self.key, self.value, color];
}

// Designated initializer.
- (instancetype)initWithKey:(id _Nullable)aKey
                  withValue:(id _Nullable)aValue
                  withColor:(FSTLLRBColor)aColor
                   withLeft:(id<FSTLLRBNode> _Nullable)aLeft
                  withRight:(id<FSTLLRBNode> _Nullable)aRight {
  self = [super init];
  if (self) {
    _key = aKey;
    _value = aValue;
    _color = aColor != FSTLLRBColorUnspecified ? aColor : FSTLLRBColorRed;
    _left = aLeft != nil ? aLeft : [FSTLLRBEmptyNode emptyNode];
    _right = aRight != nil ? aRight : [FSTLLRBEmptyNode emptyNode];
    _count = NSNotFound;
  }
  return self;
}

- (instancetype)copyWith:(id _Nullable)aKey
               withValue:(id _Nullable)aValue
               withColor:(FSTLLRBColor)aColor
                withLeft:(id<FSTLLRBNode> _Nullable)aLeft
               withRight:(id<FSTLLRBNode> _Nullable)aRight {
  return [[FSTLLRBValueNode alloc]
      initWithKey:(aKey != nil) ? aKey : self.key
        withValue:(aValue != nil) ? aValue : self.value
        withColor:(aColor != FSTLLRBColorUnspecified) ? aColor : self.color
         withLeft:(aLeft != nil) ? aLeft : self.left
        withRight:(aRight != nil) ? aRight : self.right];
}

- (void)setLeft:(nullable id<FSTLLRBNode>)left {
  // Setting the left node should be only done by the builder, so doing it after someone has
  // memoized count is an error.
  NSAssert(_count == NSNotFound, @"Can't update left node after using count");
  _left = left;
}

- (NSUInteger)count {
  if (_count == NSNotFound) {
    _count = _left.count + 1 + _right.count;
  }
  return _count;
}

- (BOOL)isEmpty {
  return NO;
}

/**
 * Early terminates if action returns YES.
 *
 * @return The first truthy value returned by action, or the last falsey value returned by action.
 */
- (BOOL)inorderTraversal:(BOOL (^)(id key, id value))action {
  return [self.left inorderTraversal:action] || action(self.key, self.value) ||
         [self.right inorderTraversal:action];
}

- (BOOL)reverseTraversal:(BOOL (^)(id key, id value))action {
  return [self.right reverseTraversal:action] || action(self.key, self.value) ||
         [self.left reverseTraversal:action];
}

- (id<FSTLLRBNode>)min {
  if ([self.left isEmpty]) {
    return self;
  } else {
    return [self.left min];
  }
}

- (nullable id)minKey {
  return [[self min] key];
}

- (nullable id)maxKey {
  if ([self.right isEmpty]) {
    return self.key;
  } else {
    return [self.right maxKey];
  }
}

- (id<FSTLLRBNode>)insertKey:(id)aKey forValue:(id)aValue withComparator:(NSComparator)aComparator {
  NSComparisonResult cmp = aComparator(aKey, self.key);
  FSTLLRBValueNode *n = self;

  if (cmp == NSOrderedAscending) {
    n = [n copyWith:nil
          withValue:nil
          withColor:FSTLLRBColorUnspecified
           withLeft:[n.left insertKey:aKey forValue:aValue withComparator:aComparator]
          withRight:nil];
  } else if (cmp == NSOrderedSame) {
    n = [n copyWith:nil
          withValue:aValue
          withColor:FSTLLRBColorUnspecified
           withLeft:nil
          withRight:nil];
  } else {
    n = [n copyWith:nil
          withValue:nil
          withColor:FSTLLRBColorUnspecified
           withLeft:nil
          withRight:[n.right insertKey:aKey forValue:aValue withComparator:aComparator]];
  }

  return [n fixUp];
}

- (id<FSTLLRBNode>)removeMin {
  if ([self.left isEmpty]) {
    return [FSTLLRBEmptyNode emptyNode];
  }

  FSTLLRBValueNode *n = self;
  if (![n.left isRed] && ![n.left.left isRed]) {
    n = [n moveRedLeft];
  }

  n = [n copyWith:nil
        withValue:nil
        withColor:FSTLLRBColorUnspecified
         withLeft:[(FSTLLRBValueNode *)n.left removeMin]
        withRight:nil];
  return [n fixUp];
}

- (id<FSTLLRBNode>)fixUp {
  FSTLLRBValueNode *n = self;
  if ([n.right isRed] && ![n.left isRed]) n = [n rotateLeft];
  if ([n.left isRed] && [n.left.left isRed]) n = [n rotateRight];
  if ([n.left isRed] && [n.right isRed]) n = [n colorFlip];
  return n;
}

- (FSTLLRBValueNode *)moveRedLeft {
  FSTLLRBValueNode *n = [self colorFlip];
  if ([n.right.left isRed]) {
    n = [n copyWith:nil
          withValue:nil
          withColor:FSTLLRBColorUnspecified
           withLeft:nil
          withRight:[(FSTLLRBValueNode *)n.right rotateRight]];
    n = [n rotateLeft];
    n = [n colorFlip];
  }
  return n;
}

- (FSTLLRBValueNode *)moveRedRight {
  FSTLLRBValueNode *n = [self colorFlip];
  if ([n.left.left isRed]) {
    n = [n rotateRight];
    n = [n colorFlip];
  }
  return n;
}

- (id<FSTLLRBNode>)rotateLeft {
  id<FSTLLRBNode> nl = [self copyWith:nil
                            withValue:nil
                            withColor:FSTLLRBColorRed
                             withLeft:nil
                            withRight:self.right.left];
  return [self.right copyWith:nil withValue:nil withColor:self.color withLeft:nl withRight:nil];
}

- (id<FSTLLRBNode>)rotateRight {
  id<FSTLLRBNode> nr = [self copyWith:nil
                            withValue:nil
                            withColor:FSTLLRBColorRed
                             withLeft:self.left.right
                            withRight:nil];
  return [self.left copyWith:nil withValue:nil withColor:self.color withLeft:nil withRight:nr];
}

- (id<FSTLLRBNode>)colorFlip {
  FSTLLRBColor color = self.color == FSTLLRBColorBlack ? FSTLLRBColorRed : FSTLLRBColorBlack;
  FSTLLRBColor leftColor =
      self.left.color == FSTLLRBColorBlack ? FSTLLRBColorRed : FSTLLRBColorBlack;
  FSTLLRBColor rightColor =
      self.right.color == FSTLLRBColorBlack ? FSTLLRBColorRed : FSTLLRBColorBlack;

  id<FSTLLRBNode> nleft =
      [self.left copyWith:nil withValue:nil withColor:leftColor withLeft:nil withRight:nil];
  id<FSTLLRBNode> nright =
      [self.right copyWith:nil withValue:nil withColor:rightColor withLeft:nil withRight:nil];

  return [self copyWith:nil withValue:nil withColor:color withLeft:nleft withRight:nright];
}

- (id<FSTLLRBNode>)remove:(id)aKey withComparator:(NSComparator)comparator {
  id<FSTLLRBNode> smallest;
  FSTLLRBValueNode *n = self;

  if (comparator(aKey, n.key) == NSOrderedAscending) {
    if (![n.left isEmpty] && ![n.left isRed] && ![n.left.left isRed]) {
      n = [n moveRedLeft];
    }
    n = [n copyWith:nil
          withValue:nil
          withColor:FSTLLRBColorUnspecified
           withLeft:[n.left remove:aKey withComparator:comparator]
          withRight:nil];
  } else {
    if ([n.left isRed]) {
      n = [n rotateRight];
    }

    if (![n.right isEmpty] && ![n.right isRed] && ![n.right.left isRed]) {
      n = [n moveRedRight];
    }

    if (comparator(aKey, n.key) == NSOrderedSame) {
      if ([n.right isEmpty]) {
        return [FSTLLRBEmptyNode emptyNode];
      } else {
        smallest = [n.right min];
        n = [n copyWith:smallest.key
              withValue:smallest.value
              withColor:FSTLLRBColorUnspecified
               withLeft:nil
              withRight:[(FSTLLRBValueNode *)n.right removeMin]];
      }
    }
    n = [n copyWith:nil
          withValue:nil
          withColor:FSTLLRBColorUnspecified
           withLeft:nil
          withRight:[n.right remove:aKey withComparator:comparator]];
  }
  return [n fixUp];
}

- (BOOL)isRed {
  return self.color == FSTLLRBColorRed;
}

- (BOOL)checkMaxDepth {
  int blackDepth = [self check];
  if (pow(2.0, blackDepth) <= ([self count] + 1)) {
    return YES;
  } else {
    return NO;
  }
}

- (int)check {
  int blackDepth = 0;

  if ([self isRed] && [self.left isRed]) {
    @throw
        [[NSException alloc] initWithName:@"check" reason:@"Red node has a red child" userInfo:nil];
  }

  if ([self.right isRed]) {
    @throw [[NSException alloc] initWithName:@"check" reason:@"Right child is red" userInfo:nil];
  }

  blackDepth = [self.left check];
  if (blackDepth != [self.right check]) {
    NSString *err =
        [NSString stringWithFormat:@"(%@ -> %@)blackDepth: %d ; self.right check: %d", self.value,
                                   self.colorDescription, blackDepth, [self.right check]];
    @throw [[NSException alloc] initWithName:@"check" reason:err userInfo:nil];
  } else {
    int ret = blackDepth + ([self isRed] ? 0 : 1);
    return ret;
  }
}

@end

NS_ASSUME_NONNULL_END
