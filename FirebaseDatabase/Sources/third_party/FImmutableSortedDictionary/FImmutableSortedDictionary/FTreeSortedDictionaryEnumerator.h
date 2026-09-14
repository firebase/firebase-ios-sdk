#import <Foundation/Foundation.h>
#import "FTreeSortedDictionary.h"

@interface FTreeSortedDictionaryEnumerator : NSEnumerator

- (id)initWithImmutableSortedDictionary:(FTreeSortedDictionary *)aDict startKey:(id)startKey isReverse:(BOOL)reverse;
- (id)nextObject;

@end
