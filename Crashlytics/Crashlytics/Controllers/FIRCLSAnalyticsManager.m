//
//  FIRCLSAnalyticsManager.m
//  Pods
//
//  Created by Sam Edson on 1/25/21.
//

#import "FIRCLSAnalyticsManager.h"

#import "Crashlytics/Crashlytics/Components/FIRCLSUserLogging.h"
#import "Crashlytics/Crashlytics/Helpers/FIRAEvent+Internal.h"
#import "Crashlytics/Crashlytics/Helpers/FIRCLSFCRAnalytics.h"

#import "Interop/Analytics/Public/FIRAnalyticsInterop.h"
#import "Interop/Analytics/Public/FIRAnalyticsInteropListener.h"

static NSString *FIRCLSFirebaseAnalyticsEventLogFormat = @"$A$:%@";

@interface FIRCLSAnalyticsManager () <FIRAnalyticsInteropListener> {
  id<FIRAnalyticsInterop> _analytics;
}

@property(nonatomic, assign) BOOL registeredAnalyticsEventListener;

@end

@implementation FIRCLSAnalyticsManager

- (instancetype)initWithAnalytics:(nullable id<FIRAnalyticsInterop>)analytics {
  self = [super init];
  if (!self) {
    return nil;
  }

  _analytics = analytics;

  return self;
}

- (void)registerAnalyticsListener {
  if (self.registeredAnalyticsEventListener) {
    return;
  }

  [FIRCLSFCRAnalytics registerEventListener:self toAnalytics:_analytics];

  self.registeredAnalyticsEventListener = YES;
}

- (void)messageTriggered:(NSString *)name parameters:(NSDictionary *)parameters {
  NSDictionary *event = @{
    @"name" : name,
    @"parameters" : parameters,
  };
  NSString *json = FIRCLSFIRAEventDictionaryToJSON(event);
  if (json != nil) {
    FIRCLSLog(FIRCLSFirebaseAnalyticsEventLogFormat, json);
  }
}

@end
