/**
 * Implementation of an immutable SortedMap using a Left-leaning
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

#import "Firestore/third_party/Immutable/FSTImmutableSortedDictionary.h"
#import "Firestore/third_party/Immutable/FSTLLRBNode.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * FSTTreeSortedDictionary is a tree-based implementation of FSTImmutableSortedDictionary.
 * You should not use this class directly. You should use FSTImmutableSortedDictionary.
 */
@interface FSTTreeSortedDictionary <KeyType, ValueType> :
    FSTImmutableSortedDictionary<KeyType, ValueType>

@property(nonatomic, copy, readonly) NSComparator comparator;
@property(nonatomic, strong, readonly) id<FSTLLRBNode> root;

- (id)init __attribute__((unavailable("Use initWithComparator:withRoot: instead.")));

- (instancetype)initWithComparator:(NSComparator)aComparator;

- (instancetype)initWithComparator:(NSComparator)aComparator
                          withRoot:(id<FSTLLRBNode>)aRoot NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
