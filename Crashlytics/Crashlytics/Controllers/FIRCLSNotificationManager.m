//
//  FIRCLSNotificationManager.m
//  Pods
//
//  Created by Sam Edson on 1/25/21.
//

#import "FIRCLSNotificationManager.h"

#import "Crashlytics/Crashlytics/Components/FIRCLSApplication.h"
#import "Crashlytics/Crashlytics/Components/FIRCLSGlobals.h"
#import "Crashlytics/Crashlytics/Components/FIRCLSUserLogging.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

@implementation FIRCLSNotificationManager

- (void)registerNotificationListener {
  [self captureInitialNotificationStates];

#if TARGET_OS_IOS
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(willBecomeActive:)
                                               name:UIApplicationWillEnterForegroundNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(didBecomeInactive:)
                                               name:UIApplicationDidEnterBackgroundNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(didChangeOrientation:)
                                               name:UIDeviceOrientationDidChangeNotification
                                             object:nil];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(didChangeUIOrientation:)
             name:UIApplicationDidChangeStatusBarOrientationNotification
           object:nil];
#pragma clang diagnostic pop

#elif CLS_TARGET_OS_OSX
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(willBecomeActive:)
                                               name:@"NSApplicationWillBecomeActiveNotification"
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(didBecomeInactive:)
                                               name:@"NSApplicationDidResignActiveNotification"
                                             object:nil];
#endif
}

- (void)captureInitialNotificationStates {
#if TARGET_OS_IOS
  UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
  UIInterfaceOrientation statusBarOrientation =
      [FIRCLSApplicationSharedInstance() statusBarOrientation];
#endif

  // It's nice to do this async, so we don't hold up the main thread while doing three
  // consecutive IOs here.
  dispatch_async(FIRCLSGetLoggingQueue(), ^{
    FIRCLSUserLoggingWriteInternalKeyValue(FIRCLSInBackgroundKey, @"0");
#if TARGET_OS_IOS
    FIRCLSUserLoggingWriteInternalKeyValue(FIRCLSDeviceOrientationKey,
                                           [@(orientation) description]);
    FIRCLSUserLoggingWriteInternalKeyValue(FIRCLSUIOrientationKey,
                                           [@(statusBarOrientation) description]);
#endif
  });
}

- (void)willBecomeActive:(NSNotification *)notification {
  FIRCLSUserLoggingRecordInternalKeyValue(FIRCLSInBackgroundKey, @NO);
}

- (void)didBecomeInactive:(NSNotification *)notification {
  FIRCLSUserLoggingRecordInternalKeyValue(FIRCLSInBackgroundKey, @YES);
}

#if TARGET_OS_IOS
- (void)didChangeOrientation:(NSNotification *)notification {
  UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];

  FIRCLSUserLoggingRecordInternalKeyValue(FIRCLSDeviceOrientationKey, @(orientation));
}

- (void)didChangeUIOrientation:(NSNotification *)notification {
  UIInterfaceOrientation statusBarOrientation =
      [FIRCLSApplicationSharedInstance() statusBarOrientation];

  FIRCLSUserLoggingRecordInternalKeyValue(FIRCLSUIOrientationKey, @(statusBarOrientation));
}
#endif

@end
