//
//  RealtimeHttpClient.swift
//  FirebaseRemoteConfigSwift
//
//  Created by Quan Pham on 3/1/22.
//

import Foundation
import FirebaseRemoteConfig
import FirebaseSharedSwift


public class RealtimeHttpClient {
    
    var urlSession: URLSession;
    var urlSessionTask: URLSessionDataTask;
    var urlRequest: NSURLRequest;
    var serverUrl: URL;
    var fetchHandler: RCNConfigFetch;
    
    public init(initRealtime fetchHandler: RCNConfigFetch) {
        
    }
    
    func setUpHttpRequest() {
        urlRequest = NSMutableURLRequest.init(url: serverUrl);
        
    }
}
