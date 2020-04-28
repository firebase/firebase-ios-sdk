/*
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#if canImport(Combine)
  import Combine
#endif
import Foundation
import FirebaseFirestore

extension Query {

  @available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
  struct DocumentPublisher<Output: DocumentSnapshot>: Publisher {
    typealias Output = DocumentSnapshot
    typealias Failure = Error
    
    private let query: Query
    
    init(query: Query) {
      self.query = query
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
      let subscription = DocumentSubscription(subscriber: subscriber, query: query)
      subscriber.receive(subscription: subscription)
    }
    
  }
  
  @available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
  public func getDocuments() -> AnyPublisher<DocumentSnapshot, Error> {
    return DocumentPublisher(query: self).eraseToAnyPublisher()
  }

  @available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
  public func dummyPublisher() -> AnyPublisher<Int, Never> {
    return Just(42).eraseToAnyPublisher()
  }  
  
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
extension Query.DocumentPublisher {
  
  @available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
  class DocumentSubscription<S: Subscriber>: Subscription where S.Input == DocumentSnapshot, S.Failure == Error {
    private let query: Query
    private var subscriber: S?
    
    init(subscriber: S, query: Query) {
      self.subscriber = subscriber
      self.query = query
    }
    
    func request(_ demand: Subscribers.Demand) {
      if (demand > 0) {
      }
    }
    
    func cancel() {
      subscriber = nil
    }
  }

}
