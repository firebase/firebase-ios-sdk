//
//   Copyright 2012 Square Inc.
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.
//

#import "FirebaseDatabase/Sources/third_party/SocketRocket/NSData+SRB64Additions.h"
#import "FirebaseDatabase/Sources/third_party/SocketRocket/fbase64.h"

@implementation FSRUtilities

+ (NSString *)base64EncodedStringFromData:(NSData *)data {
    size_t buffer_size = ((data.length * 3 + 2) / 2);

    char *buffer = (char *)malloc(buffer_size);

    int len = f_b64_ntop(data.bytes, data.length, buffer, buffer_size);

    if (len == -1) {
        free(buffer);
        return nil;
    } else{
        return [[NSString alloc] initWithBytesNoCopy:buffer length:len encoding:NSUTF8StringEncoding freeWhenDone:YES];
    }
}

@end
