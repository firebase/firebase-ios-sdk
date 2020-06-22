#import <Foundation/Foundation.h>
#import "FImmutableSortedDictionary.h"

/**
 * This is an array backed implementation of FImmutableSortedDictionary. It uses arrays and linear lookups to achieve
 * good memory efficiency while maintaining good performance for small collections. It also uses less allocations than
 * a comparable red black tree. To avoid degrading performance with increasing collection size it will automatically
 * convert to a FTreeSortedDictionary after an insert call above a certain threshold.
 */
@interface FArraySortedDictionary : FImmutableSortedDictionary

+ (FArraySortedDictionary *)fromDictionary:(NSDictionary *)dictionary withComparator:(NSComparator)comparator;

- (id)initWithComparator:(NSComparator)comparator;

#pragma mark -
#pragma mark Properties

@property (nonatomic, copy, readonly) NSComparator comparator;

@end
