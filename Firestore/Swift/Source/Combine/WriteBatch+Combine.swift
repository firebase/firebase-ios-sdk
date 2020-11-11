//
//  WriteBatch+Combine.swift
//  Forvice
//
//  Created by Lorenzo Fiamingo on 11/11/20.
//

#if canImport(Combine) && swift(>=5.0)

import Combine
import FirebaseFirestore

extension WriteBatch {
  
    /// Commits all of the writes in this write batch as a single atomic unit.
    ///
    /// - Returns: A publisher that emits a `Void` value once all of the writes in the batch
    ///   have been successfully written to the backend as an atomic unit. This publisher will only
    ///   emits when the client is online and the commit has completed against the server.
    ///   The changes will be visible immediately.
  func commitPublisher() -> Future<Void, Error> {
    Future { self.commit(completion: $0) }
  }
}

#endif
