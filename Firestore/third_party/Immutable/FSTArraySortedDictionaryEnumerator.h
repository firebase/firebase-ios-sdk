#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FSTArraySortedDictionaryEnumerator <KeyType, ValueType> : NSEnumerator<ValueType>

- (id)init __attribute__((unavailable("Use initWithKeys:startPos:endPos:isReverse: instead.")));

/**
 * An enumerator for use with a dictionary.
 *
 * @param keys The keys to enumerator within.
 * @param start The index of the initial key to return.
 * @param end If end is after (or equal to) start (or before, if reverse), then the enumerator will
 *            stop and not return the value once it reaches end.
 */
- (instancetype)initWithKeys:(NSArray<KeyType> *)keys
                    startPos:(int)start
                      endPos:(int)end
                   isReverse:(BOOL)reverse NS_DESIGNATED_INITIALIZER;

- (_Nullable ValueType)nextObject;

@end

NS_ASSUME_NONNULL_END
