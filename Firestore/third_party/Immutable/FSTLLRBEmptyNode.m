#import "Firestore/third_party/Immutable/FSTLLRBEmptyNode.h"

#import "Firestore/third_party/Immutable/FSTLLRBValueNode.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FSTLLRBEmptyNode

- (NSString *)description {
  return @"[empty node]";
}

+ (instancetype)emptyNode {
  static dispatch_once_t pred = 0;
  __strong static id _sharedObject = nil;
  dispatch_once(&pred, ^{
    _sharedObject = [[self alloc] init];  // or some other init method
  });
  return _sharedObject;
}

- (nullable id)key {
  return nil;
}

- (nullable id)value {
  return nil;
}

- (FSTLLRBColor)color {
  return FSTLLRBColorUnspecified;
}

- (nullable id<FSTLLRBNode>)left {
  return nil;
}

- (nullable id<FSTLLRBNode>)right {
  return nil;
}

- (instancetype)copyWith:(id _Nullable)aKey
               withValue:(id _Nullable)aValue
               withColor:(FSTLLRBColor)aColor
                withLeft:(id<FSTLLRBNode> _Nullable)aLeft
               withRight:(id<FSTLLRBNode> _Nullable)aRight {
  // This class is a singleton anyway, so this is more efficient than calling the constructor again.
  return self;
}

- (id<FSTLLRBNode>)insertKey:(id)aKey forValue:(id)aValue withComparator:(NSComparator)aComparator {
  FSTLLRBValueNode *result = [[FSTLLRBValueNode alloc] initWithKey:aKey
                                                         withValue:aValue
                                                         withColor:FSTLLRBColorUnspecified
                                                          withLeft:nil
                                                         withRight:nil];
  return result;
}

- (id<FSTLLRBNode>)remove:(id)key withComparator:(NSComparator)aComparator {
  return self;
}

- (NSUInteger)count {
  return 0;
}

- (BOOL)isEmpty {
  return YES;
}

- (BOOL)inorderTraversal:(BOOL (^)(id key, id value))action {
  return NO;
}

- (BOOL)reverseTraversal:(BOOL (^)(id key, id value))action {
  return NO;
}

- (id<FSTLLRBNode>)min {
  return self;
}

- (nullable id)minKey {
  return nil;
}

- (nullable id)maxKey {
  return nil;
}

- (BOOL)isRed {
  return NO;
}

- (int)check {
  return 0;
}

@end

NS_ASSUME_NONNULL_END
