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

#import "FIRAppInternal.h"
#import "FIRComponent.h"
#import "FIRComponentContainer.h"
#import "FIRComponentType.h"
#import "FirebaseCoreInternal.h"
#import "FIRHeartbeatLogger.h"
#import "FIRLibrary.h"
#import "FIRLogger.h"
#import "FIROptionsInternal.h"

FOUNDATION_EXPORT double FirebaseCoreExtensionVersionNumber;
FOUNDATION_EXPORT const unsigned char FirebaseCoreExtensionVersionString[];

