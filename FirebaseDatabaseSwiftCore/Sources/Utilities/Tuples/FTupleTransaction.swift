//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 21/04/2022.
//

import Foundation

class FTupleTransaction {
    internal init(path: FPath, update: @escaping (MutableData) -> TransactionResult, onComplete: ((Error?, Bool, DataSnapshot?) -> Void)?, status: FTransactionStatus, order: NSNumber, applyLocally: Bool, retryCount: Int, unwatcher: @escaping () -> Void, abortStatus: String? = nil, abortReason: String? = nil, currentWriteId: Int?, currentInputSnapshot: FNode?, currentOutputSnapshotRaw: FNode?, currentOutputSnapshotResolved: FNode?) {
        self.path = path
        self.update = update
        self.onComplete = onComplete
        self.status = status
        self.order = order
        self.applyLocally = applyLocally
        self.retryCount = retryCount
        self.unwatcher = unwatcher
        self.abortStatus = abortStatus
        self.abortReason = abortReason
        self.currentWriteId = currentWriteId
        self.currentInputSnapshot = currentInputSnapshot
        self.currentOutputSnapshotRaw = currentOutputSnapshotRaw
        self.currentOutputSnapshotResolved = currentOutputSnapshotResolved
    }

    let path: FPath
    let update: (MutableData) -> TransactionResult // fbt_transactionresult_mutabledata
    let onComplete: ((Error?, Bool, DataSnapshot?) -> Void)? // fbt_void_nserror_bool_datasnapshot
    var status: FTransactionStatus

    /**
     * Used when combining transaction at different locations to figure out which
     * one goes first.
     */
    let order: NSNumber

    /**
     * Whether to raise local events for this transaction
     */
    let applyLocally: Bool

    /**
     * Count how many times we've retried the transaction
     */
    var retryCount: Int


    /**
     * Function to call to clean up our listener
     */
    let unwatcher: () -> Void

    /**
     * Stores why a transaction was aborted
     */
    private(set) var abortStatus: String?
    private(set) var abortReason: String?

    func setAbortStatus(abortStatus: String?, reason: String?) {
        self.abortStatus = abortStatus
        self.abortReason = reason
    }

    var abortError: Error? {
        abortStatus.flatMap { FUtilitiesSwift.error(for: $0, reason: abortReason) }
    }


    var currentWriteId: Int?

    /**
     * Stores the input snapshot, before the update
     */
    var currentInputSnapshot: FNode?

    /**
     * Stores the unresolved (for server values) output snapshot, after the update
     */
    var currentOutputSnapshotRaw: FNode?

    /**
     * Stores the resolved (for server values) output snapshot, after the update
     */
    var currentOutputSnapshotResolved: FNode?
}
