//
//  FIRCLSAppMemoryManager.m
//
//
//  Created by Alexander Cohen on 5/6/24.
//

#import "Crashlytics/Crashlytics/Controllers/FIRCLSAppMemoryManager.h"

#import "Crashlytics/Crashlytics/Components/FIRCLSAppMemory.h"

@interface FIRCLSAppMemoryManager () {
  FIRCLSAppMemoryTracker *_tracker;
}

@end

@implementation FIRCLSAppMemoryManager

- (instancetype)init {
  if (self = [super init]) {
    _tracker = [[FIRCLSAppMemoryTracker alloc] init];
    [_tracker start];
  }
  return self;
}

@end
