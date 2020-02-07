//
//  FIRCLSRecordException.m
//  FirebaseCore-iOS
//
//  Created by Sam Edson on 2/4/20.
//

#import "FIRCLSRecordException.h"

@implementation FIRCLSRecordException

- (instancetype)initWithDict:(NSDictionary *)dict {
  self = [super initWithDict:dict];
  if ( ! self) {
    return self;
  }


  //    NSString *domain = dict[@"domain"];
  //    if (domain) {
  //      _domain = FIRCLSFileHexDecodeString([domain UTF8String]);
  //    }
  //
  //    _code = [dict[@"code"] unsignedIntegerValue];
  //    _time = [dict[@"time"] unsignedIntegerValue];
  //    _stacktrace = dict[@"stacktrace"];

  return self;
}

@end
