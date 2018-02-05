#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * FSTImmutableSortedSet is a set. It is immutable, but has methods to create new sets that are
 * mutations of it, in an efficient way.
 */
@interface FSTImmutableSortedSet <KeyType> : NSObject

+ (FSTImmutableSortedSet<KeyType> *)setWithComparator:(NSComparator)comparator;

+ (FSTImmutableSortedSet<KeyType> *)setWithKeysFromDictionary:(NSDictionary<KeyType, id> *)array
                                                   comparator:(NSComparator)comparator;

- (BOOL)containsObject:(KeyType)object;

- (FSTImmutableSortedSet<KeyType> *)setByAddingObject:(KeyType)object;
- (FSTImmutableSortedSet<KeyType> *)setByRemovingObject:(KeyType)object;

- (KeyType)firstObject;
- (KeyType)lastObject;
- (NSUInteger)count;
- (BOOL)isEmpty;

/**
 * Returns the index of the object or NSNotFound if the object is not found.
 *
 * @param object The object to return the index for.
 * @return The index of the object, or NSNotFound if not found.
 */
- (NSUInteger)indexOfObject:(KeyType)object;

- (void)enumerateObjectsUsingBlock:(void (^)(KeyType obj, BOOL *stop))block;
- (void)enumerateObjectsFrom:(KeyType)start
                          to:(_Nullable KeyType)end
                  usingBlock:(void (^)(KeyType obj, BOOL *stop))block;
- (void)enumerateObjectsReverse:(BOOL)reverse usingBlock:(void (^)(KeyType obj, BOOL *stop))block;

- (NSEnumerator<KeyType> *)objectEnumerator;
- (NSEnumerator<KeyType> *)objectEnumeratorFrom:(KeyType)startKey;

@end

NS_ASSUME_NONNULL_END
