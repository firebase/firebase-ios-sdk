// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
#if os(iOS) || os(tvOS)
  import MobileCoreServices
#elseif os(macOS) || os(watchOS)
  import CoreServices
#endif // os(iOS) || os(tvOS)

// swift(>=5.9) implies Xcode 15+
// Need to have this Swift version check to use os(visionOS) macro, VisionOS support.
// TODO: Remove this check and add `os(visionOS)` to the `os(iOS) || os(tvOS)` conditional above
// when Xcode 15 is the minimum supported by Firebase.
#if swift(>=5.9)
  #if os(visionOS)
    import MobileCoreServices
  #endif // os(visionOS)
#endif // swift(>=5.9)

class StorageUtils {
  class func defaultRequestForReference(reference: StorageReference,
                                        queryParams: [String: String]? = nil)
    -> URLRequest {
    var components = URLComponents()
    components.scheme = reference.storage.scheme
    components.host = reference.storage.host
    components.port = reference.storage.port

    if let queryParams {
      var queryItems = [URLQueryItem]()
      for (key, value) in queryParams {
        queryItems.append(URLQueryItem(name: key, value: value))
      }
      components.queryItems = queryItems
      // NSURLComponents does not encode "+" as "%2B". This is however required by our backend, as
      // it treats "+" as a shorthand encoding for spaces. See also
      // https://stackoverflow.com/questions/31577188/how-to-encode-into-2b-with-nsurlcomponents
      components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(
        of: "+",
        with: "%2B"
      )
    }
    let encodedPath = encodedURL(for: reference.path)
    components.percentEncodedPath = encodedPath
    guard let url = components.url else {
      fatalError("FirebaseStorage Internal Error: Failed to create url for \(reference.bucket)")
    }
    return URLRequest(url: url)
  }

  class func encodedURL(for path: StoragePath) -> String {
    let bucketString = "/b/\(GCSEscapedString(path.bucket))"
    var objectString: String
    if let objectName = path.object {
      objectString = "/o/\(GCSEscapedString(objectName))"
    } else {
      objectString = "/o"
    }
    return "/v0\(bucketString)\(objectString)"
  }

  class func GCSEscapedString(_ string: String) -> String {
    // This is the list at https://cloud.google.com/storage/docs/json_api/ without &, ; and +.
    let allowedSet =
      CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~!$'()*,=:@"
      )
    return string.addingPercentEncoding(withAllowedCharacters: allowedSet)!
  }

  class func MIMETypeForExtension(_ fileExtension: String?) -> String {
    guard let fileExtension = fileExtension else {
      return "application/octet-stream"
    }

    if let type = UTTypeCreatePreferredIdentifierForTag(
      kUTTagClassFilenameExtension,
      fileExtension as NSString,
      nil
    )?.takeRetainedValue() {
      if let mimeType = UTTypeCopyPreferredTagWithClass(type, kUTTagClassMIMEType)?
        .takeRetainedValue() {
        return mimeType as String
      }
    }
    return "application/octet-stream"
  }
}
