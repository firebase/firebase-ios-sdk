#import "Firestore/third_party/Immutable/FSTImmutableSortedSet.h"

NS_ASSUME_NONNULL_BEGIN

// clang-format doesn't yet deal with generic parameters and categories :-(
// clang-format off
@interface FSTImmutableSortedSet<T> (Testing)

/**
 * An array containing the set’s members, or an empty array if the set has no members.
 *
 * Implemented here for compatibility with NSSet in testing though we'd never want to do this
 * in production code.
 */
- (NSArray<T> *)allObjects;

@end
// clang-format on

NS_ASSUME_NONNULL_END
