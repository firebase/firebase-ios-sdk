#import "FIRInstanceIDCombinedHandler.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^FIRInstanseIDHandler)(id _Nullable result, NSError *_Nullable error);

@interface FIRInstanceIDCombinedHandler <ResultType>()
@property(atomic, readonly, strong) NSMutableArray<FIRInstanseIDHandler> *handlers;
@end

NS_ASSUME_NONNULL_END

@implementation FIRInstanceIDCombinedHandler

- (instancetype)init {
  self = [super init];
  if (self) {
    _handlers = [NSMutableArray array];
  }
  return self;
}

- (void)addHandler:(FIRInstanseIDHandler)handler {
  if (!handler) {
    return;
  }

  @synchronized(self) {
    [self.handlers addObject:handler];
  }
}

- (FIRInstanseIDHandler)combinedHandler {
  FIRInstanseIDHandler combinedHandler = nil;

  @synchronized(self) {
    NSArray<FIRInstanseIDHandler> *handlers = [self.handlers copy];
    combinedHandler = ^(id result, NSError *error) {
      for (FIRInstanseIDHandler handler in handlers) {
        handler(result, error);
      }
    };
  }

  return combinedHandler;
}

@end
