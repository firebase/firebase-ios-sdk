//
//  FIRCLSRecordCrashBase.h
//  FirebaseCore-iOS
//
//  Created by Sam Edson on 2/11/20.
//

#import <Foundation/Foundation.h>

#import "FIRCLSRecordBase.h"

NS_ASSUME_NONNULL_BEGIN

// An interface-only superclass to the 3 types of crashes
@interface FIRCLSRecordCrashBase : FIRCLSRecordBase

// This is set in each of the subclasses constructors
@property(nonatomic) NSUInteger time;

@end

NS_ASSUME_NONNULL_END
