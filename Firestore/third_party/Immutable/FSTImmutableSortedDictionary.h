/**
 * Implementation of an immutable SortedMap using a Left-leaning Red-Black Tree, adapted from the
 * implementation in Mugs (http://mads379.github.com/mugs/) by Mads Hartmann Jensen
 * (mads379@gmail.com).
 *
 * Original paper on Left-leaning Red-Black Trees:
 * http://www.cs.princeton.edu/~rs/talks/LLRB/LLRB.pdf
 *
 * Invariant 1: No red node has a red child
 * Invariant 2: Every leaf path has the same number of black nodes
 * Invariant 3: Only the left child can be red (left leaning)
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * The size threshold where we use a tree backed sorted map instead of an array backed sorted map.
 * This is a more or less arbitrary chosen value, that was chosen to be large enough to fit most of
 * object kind of Firebase data, but small enough to not notice degradation in performance for
 * inserting and lookups. Feel free to empirically determine this constant, but don't expect much
 * gain in real world performance.
 */
extern const NSUInteger kSortedDictionaryArrayToRBTreeSizeThreshold;

/**
 * FSTImmutableSortedDictionary is a dictionary. It is immutable, but has methods to create new
 * dictionaries that are mutations of it, in an efficient way.
 */
@interface FSTImmutableSortedDictionary <KeyType, __covariant ValueType> : NSObject

+ (FSTImmutableSortedDictionary *)dictionaryWithComparator:(NSComparator)comparator;
+ (FSTImmutableSortedDictionary *)dictionaryWithDictionary:
                                      (NSDictionary<KeyType, ValueType> *)dictionary
                                                comparator:(NSComparator)comparator;

/**
 * Creates a new dictionary identical to this one, but with a key-value pair added or updated.
 *
 * @param aValue The value to associate with the key.
 * @param aKey The key to insert/update.
 * @return A new dictionary with the added/updated value.
 */
- (FSTImmutableSortedDictionary<KeyType, ValueType> *)dictionaryBySettingObject:(ValueType)aValue
                                                                         forKey:(KeyType)aKey;

/**
 * Creates a new dictionary identical to this one, but with a key removed from it.
 *
 * @param aKey The key to remove.
 * @return A new dictionary without that value.
 */
- (FSTImmutableSortedDictionary<KeyType, ValueType> *)dictionaryByRemovingObjectForKey:
    (KeyType)aKey;

/**
 * Looks up a value in the dictionary.
 *
 * @param key The key to look up.
 * @return The value for the key, if present.
 */
- (nullable ValueType)objectForKey:(KeyType)key;

/**
 * Looks up a value in the dictionary.
 *
 * @param key The key to look up.
 * @return The value for the key, if present.
 */
- (ValueType)objectForKeyedSubscript:(KeyType)key;

/**
 * Returns the index of the key or NSNotFound if the key is not found.
 *
 * @param key The key to return the index for.
 * @return The index of the key, or NSNotFound if key not found.
 */
- (NSUInteger)indexOfKey:(KeyType)key;

/** Returns true if the dictionary contains no elements. */
- (BOOL)isEmpty;

/** Returns the number of items in this dictionary. */
- (NSUInteger)count;

/** Returns the smallest key in this dictionary. */
- (KeyType)minKey;

/** Returns the largest key in this dictionary. */
- (KeyType)maxKey;

/** Calls the given block with each of the items in this dictionary, in order. */
- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(KeyType key, ValueType value, BOOL *stop))block;

/** Calls the given block with each of the items in this dictionary, in reverse order. */
- (void)enumerateKeysAndObjectsReverse:(BOOL)reverse
                            usingBlock:(void (^)(KeyType key, ValueType value, BOOL *stop))block;

/** Returns true if the dictionary contains the given key. */
- (BOOL)containsKey:(KeyType)key;

- (NSEnumerator<KeyType> *)keyEnumerator;
- (NSEnumerator<KeyType> *)keyEnumeratorFrom:(KeyType)startKey;
/** Enumerator for the range [startKey, endKey). */
- (NSEnumerator<KeyType> *)keyEnumeratorFrom:(KeyType)startKey to:(nullable KeyType)endKey;
- (NSEnumerator<KeyType> *)reverseKeyEnumerator;
- (NSEnumerator<KeyType> *)reverseKeyEnumeratorFrom:(KeyType)startKey;

@end

NS_ASSUME_NONNULL_END
