#import <Foundation/Foundation.h>

#import "Firestore/third_party/Immutable/FSTImmutableSortedDictionary.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * FSTArraySortedDictionary is an array backed implementation of FSTImmutableSortedDictionary.
 *
 * You should not use this class directly. You should use FSTImmutableSortedDictionary.
 *
 * FSTArraySortedDictionary uses arrays and linear lookups to achieve good memory efficiency while
 * maintaining good performance for small collections. It also uses fewer allocations than a
 * comparable red black tree. To avoid degrading performance with increasing collection size it
 * will automatically convert to a FSTTreeSortedDictionary after an insert call above a certain
 * threshold.
 */
@interface FSTArraySortedDictionary <KeyType, ValueType> :
    FSTImmutableSortedDictionary<KeyType, ValueType>

+ (FSTArraySortedDictionary<KeyType, ValueType> *)
    dictionaryWithDictionary:(NSDictionary<KeyType, ValueType> *)dictionary
                  comparator:(NSComparator)comparator;

- (id)init __attribute__((unavailable("Use initWithComparator:keys:values: instead.")));

- (instancetype)initWithComparator:(NSComparator)comparator;

- (instancetype)initWithComparator:(NSComparator)comparator
                              keys:(NSArray<KeyType> *)keys
                            values:(NSArray<ValueType> *)values NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
