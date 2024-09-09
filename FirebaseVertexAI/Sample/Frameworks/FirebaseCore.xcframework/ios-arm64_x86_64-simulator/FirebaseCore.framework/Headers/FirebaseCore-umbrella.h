#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "FIRApp.h"
#import "FIRConfiguration.h"
#import "FIRLoggerLevel.h"
#import "FIROptions.h"
#import "FIRTimestamp.h"
#import "FIRVersion.h"
#import "FirebaseCore.h"

FOUNDATION_EXPORT double FirebaseCoreVersionNumber;
FOUNDATION_EXPORT const unsigned char FirebaseCoreVersionString[];
