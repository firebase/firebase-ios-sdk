//
//  GDTCORApplicationFake.m
//  Pods
//
//  Created by Maksym Malyhin on 2020-09-14.
//

#import "GoogleDataTransport/GDTCORTests/Common/Fakes/GDTCORApplicationFake.h"

@implementation GDTCORApplicationFake

@synthesize isRunningInBackground;

- (GDTCORBackgroundIdentifier)beginBackgroundTaskWithName:(NSString *)name
                                        expirationHandler:(void (^__nullable)(void))handler {
  return self.beginTaskHandler(name, handler);
}

- (void)endBackgroundTask:(GDTCORBackgroundIdentifier)bgID {
  self.endTaskHandler(bgID);
}

@end
