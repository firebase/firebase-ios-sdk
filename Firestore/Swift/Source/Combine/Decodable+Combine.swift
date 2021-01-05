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

  import Foundation
  import FirebaseFirestore

  @available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
  extension Publisher where Output == QuerySnapshot {
    
    /**
     * Decodes the output `QuerySnapshot` from the upstream.
     *
     * This method returns a publisher that decodes a given type
     * which must conform to the `Decodable` protocol.
     *
     * ```
     * let noBooks = [Book]()
     * db.collection("books").getDocuments()
     *   .decode(type: Book.self)
     *   .collect()
     *   .replaceError(with: noBooks)
     *   .assign(to: \.books, on: self)
     *   .store(in: &cancellables)
     * ```
     */
    func decode<Item>(type: Item.Type) -> AnyPublisher<Item, Error> where Item: Decodable {
        mapError { $0 }
            .flatMap { Publishers.FIRDecoder(snapshot: $0) }
            .eraseToAnyPublisher()
    }
  }

  @available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
  extension Publishers {
    
    struct FIRDecoder<T: Decodable>: Publisher {
        typealias Output = T
        typealias Failure = Error
        
        private let snapshot: QuerySnapshot
        
        init(snapshot: QuerySnapshot) {
            self.snapshot = snapshot
        }
        
        func receive<S>(subscriber: S) where S : Subscriber, Self.Failure == S.Failure,
            Self.Output == S.Input {
            let subscription = FIRDecoderSubscription(for: subscriber, snapshot: snapshot)
            subscriber.receive(subscription: subscription)
        }
    }
  }

  @available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
  fileprivate final class FIRDecoderSubscription<S: Subscriber, Output: Decodable>: Subscription
    where S.Input == Output, S.Failure == Error {
    private let snapshot: QuerySnapshot
    private var subscriber: S?
    
    init(for subscriber: S, snapshot: QuerySnapshot) {
        self.subscriber = subscriber
        self.snapshot = snapshot
    }
    
    func request(_ demand: Subscribers.Demand) {
        for document in snapshot.documents {
            do {
                if let data = try document.data(as: Output.self) {
                    _ = subscriber?.receive(data)
                }
            } catch {
                subscriber?.receive(completion: .failure(error))
            }
        }
        
        subscriber?.receive(completion: .finished)
    }
    
    func cancel() {
        subscriber = nil
    }
  }
#endif
