#import "FirebaseDatabase/Sources/third_party/FImmutableSortedDictionary/FImmutableSortedDictionary/FTreeSortedDictionaryEnumerator.h"

@interface FTreeSortedDictionaryEnumerator()
@property (nonatomic, strong) FTreeSortedDictionary* immutableSortedDictionary;
@property (nonatomic, strong) NSMutableArray* stack;
@property (nonatomic) BOOL isReverse;

@end

@implementation FTreeSortedDictionaryEnumerator

- (id)initWithImmutableSortedDictionary:(FTreeSortedDictionary *)aDict
                               startKey:(id)startKey isReverse:(BOOL)reverse {
    self = [super init];
    if (self) {
        self.immutableSortedDictionary = aDict;
        self.stack = [[NSMutableArray alloc] init];
        self.isReverse = reverse;

        NSComparator comparator = aDict.comparator;
        id<FLLRBNode> node = self.immutableSortedDictionary.root;

        NSInteger cmp;
        while(![node isEmpty]) {
            cmp = startKey ? comparator(node.key, startKey) : 1;
            // flip the comparison if we're going in reverse
            if (self.isReverse) cmp *= -1;

            if (cmp < 0) {
                // This node is less than our start key. Ignore it.
                if (self.isReverse) {
                    node = node.left;
                } else {
                    node = node.right;
                }
            } else if (cmp == 0) {
                // This node is exactly equal to our start key. Push it on the stack, but stop iterating:
                [self.stack addObject:node];
                break;
            } else {
                // This node is greater than our start key, add it to the stack and move on to the next one.
                [self.stack addObject:node];
                if (self.isReverse) {
                    node = node.right;
                } else {
                    node = node.left;
                }
            }
        }
    }
    return self;
}

- (id)nextObject {
    if([self.stack count] == 0) {
        return nil;
    }

    id<FLLRBNode> node = nil;
    @synchronized(self.stack) {
        node = [self.stack lastObject];
        [self.stack removeLastObject];
    }
    id result = node.key;

    if (self.isReverse) {
        node = node.left;
        while (![node isEmpty]) {
            [self.stack addObject:node];
            node = node.right;
        }
    } else {
        node = node.right;
        while (![node isEmpty]) {
            [self.stack addObject:node];
            node = node.left;
        }
    }

    return result;
}

@end
