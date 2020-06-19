#import "FirebaseDatabase/Sources/third_party/FImmutableSortedDictionary/FImmutableSortedDictionary/FTreeSortedDictionary.h"
#import "FirebaseDatabase/Sources/third_party/FImmutableSortedDictionary/FImmutableSortedDictionary/FLLRBEmptyNode.h"
#import "FirebaseDatabase/Sources/third_party/FImmutableSortedDictionary/FImmutableSortedDictionary/FLLRBValueNode.h"
#import "FirebaseDatabase/Sources/third_party/FImmutableSortedDictionary/FImmutableSortedDictionary/FTreeSortedDictionaryEnumerator.h"

typedef void (^fbt_void_nsnumber_int)(NSNumber* color, NSUInteger chunkSize);

@interface FTreeSortedDictionary ()

@property (nonatomic, strong) id<FLLRBNode> root;
@property (nonatomic, copy, readwrite) NSComparator comparator;

@end

@implementation FTreeSortedDictionary

- (id)initWithComparator:(NSComparator)aComparator {
    self = [super init];
    if (self) {
        self.root = [FLLRBEmptyNode emptyNode];
        self.comparator = aComparator;
    }
    return self;
}

- (id)initWithComparator:(NSComparator)aComparator withRoot:(__unsafe_unretained id<FLLRBNode>)aRoot {
    self = [super init];
    if (self) {
        self.root = aRoot;
        self.comparator = aComparator;
    }
    return self;
}

/**
 * Returns a copy of the map, with the specified key/value added or replaced.
 */
- (FTreeSortedDictionary *) insertKey:(__unsafe_unretained id)aKey withValue:(__unsafe_unretained id)aValue {
    return [[FTreeSortedDictionary alloc] initWithComparator:self.comparator
                                                    withRoot:[[self.root insertKey:aKey forValue:aValue withComparator:self.comparator]
                                                              copyWith:nil
                                                              withValue:nil
                                                              withColor:BLACK
                                                              withLeft:nil
                                                              withRight:nil]];
}


- (FTreeSortedDictionary *) removeKey:(__unsafe_unretained id)aKey {
    // Remove is somewhat expensive even if the key doesn't exist (the tree does rebalancing and stuff).  So avoid it.
    if (![self contains:aKey]) {
        return self;
    } else {
        return [[FTreeSortedDictionary alloc]
                initWithComparator:self.comparator
                withRoot:[[self.root remove:aKey withComparator:self.comparator]
                          copyWith:nil
                          withValue:nil
                          withColor:BLACK
                          withLeft:nil
                          withRight:nil]];
    }
}

- (id) get:(__unsafe_unretained id) key {
    if (key == nil) {
        return nil;
    }
    NSComparisonResult cmp;
    id<FLLRBNode> node = self.root;
    while(![node isEmpty]) {
        cmp = self.comparator(key, node.key);
        if(cmp == NSOrderedSame) {
            return node.value;
        }
        else if (cmp == NSOrderedAscending) {
            node = node.left;
        }
        else {
            node = node.right;
        }
    }
    return nil;
}

- (id) getPredecessorKey:(__unsafe_unretained id) key {
    NSComparisonResult cmp;
    id<FLLRBNode> node = self.root;
    id<FLLRBNode> rightParent = nil;
    while(![node isEmpty]) {
        cmp = self.comparator(key, node.key);
        if(cmp == NSOrderedSame) {
            if(![node.left isEmpty]) {
                node = node.left;
                while(! [node.right isEmpty]) {
                    node = node.right;
                }
                return node.key;
            }
            else if (rightParent != nil) {
                return rightParent.key;
            }
            else {
                return nil;
            }
        }
        else if (cmp == NSOrderedAscending) {
            node = node.left;
        }
        else if (cmp == NSOrderedDescending) {
            rightParent = node;
            node = node.right;
        }
    }
    @throw [NSException exceptionWithName:@"NonexistentKey" reason:@"getPredecessorKey called with nonexistent key." userInfo:@{@"key": [key description] }];
}

- (BOOL) isEmpty {
    return [self.root isEmpty];
}

- (int) count {
    return [self.root count];
}

- (id) minKey {
    return [self.root minKey];
}

- (id) maxKey {
    return [self.root maxKey];
}

- (void) enumerateKeysAndObjectsUsingBlock:(void (^)(id, id, BOOL *))block
{
    [self enumerateKeysAndObjectsReverse:NO usingBlock:block];
}

- (void) enumerateKeysAndObjectsReverse:(BOOL)reverse usingBlock:(void (^)(id, id, BOOL *))block
{
    if (reverse) {
        __block BOOL stop = NO;
        [self.root reverseTraversal:^BOOL(id key, id value) {
            block(key, value, &stop);
            return stop;
        }];
    } else {
        __block BOOL stop = NO;
        [self.root inorderTraversal:^BOOL(id key, id value) {
            block(key, value, &stop);
            return stop;
        }];
    }
}

- (BOOL) contains:(__unsafe_unretained id)key {
    return ([self objectForKey:key] != nil);
}

- (NSEnumerator *) keyEnumerator {
    return [[FTreeSortedDictionaryEnumerator alloc]
            initWithImmutableSortedDictionary:self startKey:nil isReverse:NO];
}

- (NSEnumerator *) keyEnumeratorFrom:(id)startKey {
    return [[FTreeSortedDictionaryEnumerator alloc]
            initWithImmutableSortedDictionary:self startKey:startKey isReverse:NO];
}

- (NSEnumerator *) reverseKeyEnumerator {
    return [[FTreeSortedDictionaryEnumerator alloc]
            initWithImmutableSortedDictionary:self startKey:nil isReverse:YES];
}

- (NSEnumerator *) reverseKeyEnumeratorFrom:(id)startKey {
    return [[FTreeSortedDictionaryEnumerator alloc]
            initWithImmutableSortedDictionary:self startKey:startKey isReverse:YES];
}


#pragma mark -
#pragma mark Tree Builder

// Code to efficiently build a RB Tree
typedef struct _base1_2list {
    unsigned int bits;
    unsigned short count;
    unsigned short current;
} Base1_2List;

Base1_2List *base1_2List_new(unsigned int length);
void base1_2List_free(Base1_2List* list);
unsigned int log_base2(unsigned int num);
BOOL base1_2List_next(Base1_2List* list);

unsigned int log_base2(unsigned int num) {
    return (unsigned int)(log(num) / log(2));
}

/**
 * Works like an iterator, so it moves to the next bit. Do not call more than list->count times.
 * @return whether or not the next bit is a 1 in base {1,2}.
 */
BOOL base1_2List_next(Base1_2List* list) {
    BOOL result = !(list->bits & (0x1 << list->current));
    list->current--;
    return result;
}

static inline unsigned bit_mask(int x) {
    return (x >= sizeof(unsigned) * CHAR_BIT) ? (unsigned) -1 : (1U << x) - 1;
}

/**
 * We represent the base{1,2} number as the combination of a binary number and a number of bits that we care about
 * We iterate backwards, from most significant bit to least, to build up the llrb nodes. 0 base 2 => 1 base {1,2}, 1 base 2 => 2 base {1,2}
 */
Base1_2List *base1_2List_new(unsigned int length) {
    size_t sz = sizeof(Base1_2List);
    Base1_2List* list = calloc(1, sz);
    // Calculate the number of bits that we care about
    list->count = (unsigned short)log_base2(length + 1);
    unsigned int mask = bit_mask(list->count);
    list->bits = (length + 1) & mask;
    list->current = list->count - 1;
    return list;
}


void base1_2List_free(Base1_2List* list) {
    free(list);
}

+ (id<FLLRBNode>) buildBalancedTree:(NSArray *)keys dictionary:(NSDictionary *)dictionary subArrayStartIndex:(NSUInteger)startIndex length:(NSUInteger)length {
    length = MIN(keys.count - startIndex, length); // Bound length by the actual length of the array
    if (length == 0) {
        return nil;
    } else if (length == 1) {
        id key = keys[startIndex];
        return [[FLLRBValueNode alloc] initWithKey:key withValue:dictionary[key] withColor:BLACK withLeft:nil withRight:nil];
    } else {
        NSUInteger middle = length / 2;
        id<FLLRBNode> left = [FTreeSortedDictionary buildBalancedTree:keys dictionary:dictionary subArrayStartIndex:startIndex length:middle];
        id<FLLRBNode> right = [FTreeSortedDictionary buildBalancedTree:keys dictionary:dictionary subArrayStartIndex:(startIndex+middle+1) length:middle];
        id key = keys[startIndex + middle];
        return [[FLLRBValueNode alloc] initWithKey:key withValue:dictionary[key] withColor:BLACK withLeft:left withRight:right];
    }
}

+ (id<FLLRBNode>) rootFrom12List:(Base1_2List *)base1_2List keyList:(NSArray *)keyList dictionary:(NSDictionary *)dictionary {
    __block id<FLLRBNode> root = nil;
    __block id<FLLRBNode> node = nil;
    __block NSUInteger index = keyList.count;

    fbt_void_nsnumber_int buildPennant = ^(NSNumber* color, NSUInteger chunkSize) {
        NSUInteger startIndex = index - chunkSize + 1;
        index -= chunkSize;
        id key = keyList[index];
        id<FLLRBNode> childTree = [self buildBalancedTree:keyList dictionary:dictionary subArrayStartIndex:startIndex length:(chunkSize - 1)];
        id<FLLRBNode> pennant = [[FLLRBValueNode alloc] initWithKey:key withValue:dictionary[key] withColor:color withLeft:nil withRight:childTree];
        //attachPennant(pennant);
        if (node) {
            node.left = pennant;
            node = pennant;
        } else {
            root = pennant;
            node = pennant;
        }
    };

    for (int i = 0; i < base1_2List->count; ++i) {
        BOOL isOne = base1_2List_next(base1_2List);
        NSUInteger chunkSize = (NSUInteger)pow(2.0, base1_2List->count - (i + 1));
        if (isOne) {
            buildPennant(BLACK, chunkSize);
        } else {
            buildPennant(BLACK, chunkSize);
            buildPennant(RED, chunkSize);
        }
    }
    return root;
}

/**
 * Uses the algorithm linked here:
 * http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.46.1458
 */

+ (FImmutableSortedDictionary *)fromDictionary:(NSDictionary *)dictionary withComparator:(NSComparator)comparator
{
    // Steps:
    // 0. Sort the array
    // 1. Calculate the 1-2 number
    // 2. Build From 1-2 number
    //   0. for each digit in 1-2 number
    //     0. calculate chunk size
    //     1. build 1 or 2 pennants of that size
    //     2. attach pennants and update node pointer
    //   1. return root
    NSMutableArray *sortedKeyList = [NSMutableArray arrayWithCapacity:dictionary.count];
    [dictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [sortedKeyList addObject:key];
    }];
    [sortedKeyList sortUsingComparator:comparator];

    [sortedKeyList enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if (idx > 0) {
            if (comparator(sortedKeyList[idx - 1], obj) != NSOrderedAscending) {
                [NSException raise:NSInvalidArgumentException format:@"Can't create FImmutableSortedDictionary with keys with same ordering!"];
            }
        }
    }];

    Base1_2List* list = base1_2List_new((unsigned int)sortedKeyList.count);
    id<FLLRBNode> root = [self rootFrom12List:list keyList:sortedKeyList dictionary:dictionary];
    base1_2List_free(list);

    if (root != nil) {
        return [[FTreeSortedDictionary alloc] initWithComparator:comparator withRoot:root];
    } else {
        return [[FTreeSortedDictionary alloc] initWithComparator:comparator];
    }
}

@end

