#import "FirebaseDatabase/Sources/third_party/FImmutableSortedDictionary/FImmutableSortedDictionary/FImmutableSortedSet.h"
#import "FirebaseDatabase/Sources/third_party/FImmutableSortedDictionary/FImmutableSortedDictionary/FImmutableSortedDictionary.h"

@interface FImmutableSortedSet ()

@property (nonatomic, strong) FImmutableSortedDictionary *dictionary;

@end

@implementation FImmutableSortedSet

+ (FImmutableSortedSet *)setWithKeysFromDictionary:(NSDictionary *)dictionary comparator:(NSComparator)comparator
{
    FImmutableSortedDictionary *setDict = [FImmutableSortedDictionary fromDictionary:dictionary withComparator:comparator];
    return [[FImmutableSortedSet alloc] initWithDictionary:setDict];
}

- (id)initWithDictionary:(FImmutableSortedDictionary *)dictionary
{
    self = [super init];
    if (self != nil) {
        self->_dictionary = dictionary;
    }
    return self;
}

- (BOOL)contains:(id)object
{
    return [self.dictionary contains:object];
}

- (FImmutableSortedSet *)addObject:(id)object
{
    FImmutableSortedDictionary *newDictionary = [self.dictionary insertKey:object withValue:[NSNull null]];
    if (newDictionary != self.dictionary) {
        return [[FImmutableSortedSet alloc] initWithDictionary:newDictionary];
    } else {
        return self;
    }
}

- (FImmutableSortedSet *)removeObject:(id)object
{
    FImmutableSortedDictionary *newDictionary = [self.dictionary removeObjectForKey:object];
    if (newDictionary != self.dictionary) {
        return [[FImmutableSortedSet alloc] initWithDictionary:newDictionary];
    } else {
        return self;
    }
}

- (BOOL)containsObject:(id)object
{
    return [self.dictionary contains:object];
}

- (id)firstObject
{
    return [self.dictionary minKey];
}

- (id)lastObject
{
    return [self.dictionary maxKey];
}

- (id)predecessorEntry:(id)entry
{
    return [self.dictionary getPredecessorKey:entry];
}

- (NSUInteger)count
{
    return [self.dictionary count];
}

- (BOOL)isEmpty
{
    return [self.dictionary isEmpty];
}

- (void)enumerateObjectsUsingBlock:(void (^)(id, BOOL *))block
{
    [self enumerateObjectsReverse:NO usingBlock:block];
}

- (void)enumerateObjectsReverse:(BOOL)reverse usingBlock:(void (^)(id, BOOL *))block
{
    [self.dictionary enumerateKeysAndObjectsReverse:reverse usingBlock:^(id key, id value, BOOL *stop) {
        block(key, stop);
    }];
}

- (NSEnumerator *)objectEnumerator
{
    return [self.dictionary keyEnumerator];
}

- (NSString *)description
{
    NSMutableString *str = [[NSMutableString alloc] init];
    __block BOOL first = YES;
    [str appendString:@"FImmutableSortedSet ( "];
    [self enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
        if (!first) {
            [str appendString:@", "];
        }
        first = NO;
        [str appendString:[NSString stringWithFormat:@"%@", obj]];
    }];
    [str appendString:@" )"];
    return str;
}

@end
