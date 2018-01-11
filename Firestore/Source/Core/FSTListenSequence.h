#import <Foundation/Foundation.h>

#import "FSTTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTListenSequence : NSObject

- (instancetype)initStartingAfter:(FSTListenSequenceNumber)after NS_DESIGNATED_INITIALIZER;

- (id)init __attribute__((unavailable("Use a static constructor method")));

- (FSTListenSequenceNumber)next;

@end

NS_ASSUME_NONNULL_END