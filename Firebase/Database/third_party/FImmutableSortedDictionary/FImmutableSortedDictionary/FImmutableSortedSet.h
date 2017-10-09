#import <Foundation/Foundation.h>

@interface FImmutableSortedSet : NSObject

+ (FImmutableSortedSet *)setWithKeysFromDictionary:(NSDictionary *)array comparator:(NSComparator)comparator;

- (BOOL)containsObject:(id)object;
- (FImmutableSortedSet *)addObject:(id)object;
- (FImmutableSortedSet *)removeObject:(id)object;
- (id)firstObject;
- (id)lastObject;
- (NSUInteger)count;
- (BOOL)isEmpty;

- (id)predecessorEntry:(id)entry;

- (void)enumerateObjectsUsingBlock:(void (^)(id obj, BOOL *stop))block;
- (void)enumerateObjectsReverse:(BOOL)reverse usingBlock:(void (^)(id obj, BOOL *stop))block;

- (NSEnumerator *)objectEnumerator;

@end
