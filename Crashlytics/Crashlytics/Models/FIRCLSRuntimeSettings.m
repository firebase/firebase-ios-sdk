//
//  FIRCLSRuntimeSettings.m
//  FirebaseCore
//
//  Created by Sam Edson on 4/27/20.
//

#import "FIRCLSRuntimeSettings.h"

#import "FIRCLSLogger.h"

NSString *const kFIRCLSDevelopmentModeArgument = @"FIRCLSDevelopmentModeEnabled";
NSString *const kFIRCLSGDTEnabledArgument = @"FIRCLSGDTEnabled";

@interface FIRCLSRuntimeSettings ()

@property(nonatomic) BOOL isDevelopmentMode;
@property(nonatomic) BOOL isGDTEnabled;

@end

@implementation FIRCLSRuntimeSettings

- (instancetype)init {
  self = [super init];
  if (!self) {
    return nil;
  }

  _isDevelopmentMode = false;
  _isGDTEnabled = false;

  NSBundle *mainBundle = [NSBundle mainBundle];
  if (!mainBundle) {
    return self;
  }

  _isDevelopmentMode =
      [[mainBundle objectForInfoDictionaryKey:kFIRCLSDevelopmentModeArgument] boolValue];
  if (_isDevelopmentMode) {
    FIRCLSInfoLog(@"Rumtime Settings: Running Crashlytics SDK in Development Mode");
  }

  _isGDTEnabled = [[mainBundle objectForInfoDictionaryKey:kFIRCLSGDTEnabledArgument] boolValue];
  if (_isGDTEnabled) {
    FIRCLSInfoLog(@"Rumtime Settings: Forcing on GDT report uploader");
  }

  return self;
}

@end
