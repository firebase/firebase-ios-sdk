//
//  File.swift
//  
//
//  Created by Aashish Patil on 12/5/23.
//

import Foundation


@available (macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public enum DataConnectError: Error {

  //no firebase app specified. configure not complete
  case appNotConfigured

  case grpcNotConfigured

  case decodeFailed

}
