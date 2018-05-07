#import "Firestore/Example/Tests/Local/FSTLRUGarbageCollectorTests.h"

#import "Firestore/Example/Tests/Local/FSTPersistenceTestHelpers.h"
#import "Firestore/Source/Local/FSTLRUGarbageCollector.h"
#import "Firestore/Source/Local/FSTMemoryPersistence.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTMemoryLRUGarbageCollectionTests : FSTLRUGarbageCollectorTests
@end

@implementation FSTMemoryLRUGarbageCollectionTests

- (id<FSTPersistence>)newPersistence {
  return [FSTPersistenceTestHelpers lruMemoryPersistence];
}

@end

NS_ASSUME_NONNULL_END