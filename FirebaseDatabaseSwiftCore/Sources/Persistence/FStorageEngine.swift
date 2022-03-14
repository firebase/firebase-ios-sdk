//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 05/03/2022.
//

import Foundation

@objc public protocol FStorageEngine: NSObjectProtocol {
    func close()
    func saveUserOverwrite(_ node: FNode, atPath path: FPath, writeId: Int)
    func saveUserMerge(_ merge: FCompoundWrite, atPath path: FPath, writeId: Int)
    func removeUserWrite(_ writeId: Int)
    func removeAllUserWrites()
    var userWrites: [FWriteRecord] { get }
    func serverCache(atPath path: FPath) -> FNode
    func serverCache(forKeys keys: Set<String>, atPath path: FPath) -> FNode
    func updateServerCache(_ node: FNode, atPath path: FPath, merge: Bool)
    func updateServerCache(merge: FCompoundWrite, atPath path: FPath)
    var serverCacheEstimatedSizeInBytes: Int { get }
    func pruneCache(_ pruneForest: FPruneForest, atPath path: FPath)
    func loadTrackedQueries() -> [FTrackedQuery]
    func removeTrackedQuery(_ queryId: Int)
    func saveTrackedQuery(_ query: FTrackedQuery)
    func setTrackedQueryKeys(_ keys: Set<String>, forQueryId: Int)
    func updateTrackedQueryKeys(addedKeys added: Set<String>, removedKeys removed: Set<String>, forQueryId queryId: Int)
    func trackedQueryKeysForQuery(_ queryId: Int) -> Set<String>
}
