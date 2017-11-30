#import <Foundation/Foundation.h>

#import "Firestore/third_party/Immutable/FSTTreeSortedDictionary.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTTreeSortedDictionaryEnumerator <KeyType, ValueType> : NSEnumerator<ValueType>

- (id)init __attribute__((
    unavailable("Use initWithImmutableSortedDictionary:startKey:isReverse: instead.")));

- (instancetype)initWithImmutableSortedDictionary:
                    (FSTTreeSortedDictionary<KeyType, ValueType> *)aDict
                                         startKey:(KeyType _Nullable)startKey
                                           endKey:(KeyType _Nullable)endKey
                                        isReverse:(BOOL)reverse NS_DESIGNATED_INITIALIZER;
- (nullable ValueType)nextObject;

@end

NS_ASSUME_NONNULL_END
