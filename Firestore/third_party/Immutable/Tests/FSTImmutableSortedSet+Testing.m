#import "Firestore/third_party/Immutable/Tests/FSTImmutableSortedSet+Testing.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FSTImmutableSortedSet (Testing)

- (NSArray<id> *)allObjects {
  NSMutableArray<id> *result = [NSMutableArray array];
  [self enumerateObjectsUsingBlock:^(id object, BOOL *stop) {
    [result addObject:object];
  }];
  return result;
}

@end

NS_ASSUME_NONNULL_END
