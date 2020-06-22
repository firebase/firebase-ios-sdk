/**
 * @fileoverview Implementation of an immutable SortedMap using a Left-leaning
 * Red-Black Tree, adapted from the implementation in Mugs
 * (http://mads379.github.com/mugs/) by Mads Hartmann Jensen
 * (mads379@gmail.com).
 *
 * Original paper on Left-leaning Red-Black Trees:
 *   http://www.cs.princeton.edu/~rs/talks/LLRB/LLRB.pdf
 *
 * Invariant 1: No red node has a red child
 * Invariant 2: Every leaf path has the same number of black nodes
 * Invariant 3: Only the left child can be red (left leaning)
 */

#import <Foundation/Foundation.h>
#import "FirebaseDatabase/Sources/third_party/FImmutableSortedDictionary/FImmutableSortedDictionary/FImmutableSortedDictionary.h"
#import "FirebaseDatabase/Sources/third_party/FImmutableSortedDictionary/FImmutableSortedDictionary/FLLRBNode.h"

@interface FTreeSortedDictionary : FImmutableSortedDictionary

@property (nonatomic, copy, readonly) NSComparator comparator;
@property (nonatomic, strong, readonly) id<FLLRBNode> root;

- (id)initWithComparator:(NSComparator)aComparator;

// Override methods to return subtype
- (FTreeSortedDictionary *) insertKey:(id)aKey withValue:(id)aValue;
- (FTreeSortedDictionary *) removeKey:(id)aKey;

@end
