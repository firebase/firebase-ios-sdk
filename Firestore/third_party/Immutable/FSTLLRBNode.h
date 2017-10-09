#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A FSTLLRBColor is the color of a tree node. It can be RED, BLACK, or unset.
 */
typedef NS_ENUM(NSInteger, FSTLLRBColor) {
  FSTLLRBColorUnspecified = 0,
  FSTLLRBColorRed = 1,
  FSTLLRBColorBlack = 2,
};

/**
 * FSTLLRBNode is the interface for a node in a FSTTreeSortedDictionary.
 */
@protocol FSTLLRBNode <NSObject>

/**
 * Creates a copy of the given node, changing any values that were specified.
 * For any parameter that is left as nil, this instance's value will be used.
 */
- (instancetype)copyWith:(nullable id)aKey
               withValue:(nullable id)aValue
               withColor:(FSTLLRBColor)aColor
                withLeft:(nullable id<FSTLLRBNode>)aLeft
               withRight:(nullable id<FSTLLRBNode>)aRight;

/** Returns a tree node with the given key-value pair set/updated. */
- (id<FSTLLRBNode>)insertKey:(id)aKey forValue:(id)aValue withComparator:(NSComparator)aComparator;

/** Returns a tree node with the given key removed. */
- (id<FSTLLRBNode>)remove:(id)key withComparator:(NSComparator)aComparator;

/** Returns the number of elements at this node or beneath it in the tree. */
- (NSUInteger)count;

/** Returns true if this is an FSTLLRBEmptyNode -- a leaf node in the tree. */
- (BOOL)isEmpty;

- (BOOL)inorderTraversal:(BOOL (^)(id key, id value))action;
- (BOOL)reverseTraversal:(BOOL (^)(id key, id value))action;

/** Returns the left-most node under (or including) this node. */
- (id<FSTLLRBNode>)min;

/** Returns the key of the left-most node under (or including) this node. */
- (nullable id)minKey;

/** Returns the key of the right-most node under (or including) this node. */
- (nullable id)maxKey;

/** Returns true if this node is red (as opposed to black). */
- (BOOL)isRed;

/** Checks that this node and below it hold the red-black invariants. Throws otherwise. */
- (int)check;

// Accessors for properties.
- (nullable id)key;
- (nullable id)value;
- (FSTLLRBColor)color;
- (nullable id<FSTLLRBNode>)left;
- (nullable id<FSTLLRBNode>)right;

@end

NS_ASSUME_NONNULL_END
