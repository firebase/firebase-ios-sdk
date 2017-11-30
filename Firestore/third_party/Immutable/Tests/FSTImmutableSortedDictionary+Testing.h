#import <Foundation/Foundation.h>

#import "Firestore/third_party/Immutable/FSTImmutableSortedDictionary.h"

NS_ASSUME_NONNULL_BEGIN

// clang-format doesn't yet deal with generic parameters and categories :-(
// clang-format off
@interface FSTImmutableSortedDictionary<KeyType, __covariant ValueType> (Testing)

/** Converts the values of the dictionary to an array preserving order. */
- (NSArray<ValueType> *)values;

@end
// clang-format on

NS_ASSUME_NONNULL_END
