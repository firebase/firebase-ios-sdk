#import "FSTImmutableSortedDictionary+Testing.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FSTImmutableSortedDictionary (Testing)

- (NSArray<id> *)values {
  NSMutableArray<id> *result = [NSMutableArray array];
  [self enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
    [result addObject:value];
  }];
  return result;
}

@end

NS_ASSUME_NONNULL_END
