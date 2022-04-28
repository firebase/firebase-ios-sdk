//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 21/04/2022.
//

import Foundation

/**
 * Used for runTransactionBlock:. An FIRTransactionResult instance is a
 * container for the results of the transaction.
 */
@objc(FIRTransactionResult) public class TransactionResult: NSObject {
    internal init(isSuccess: Bool, update: MutableData?) {
        self.isSuccess = isSuccess
        self.update = update
    }


    var isSuccess: Bool
    var update: MutableData?

    /**
     * Used for runTransactionBlock:. Indicates that the new value should be saved
     * at this location
     *
     * @param value A FIRMutableData instance containing the new value to be set
     * @return An FIRTransactionResult instance that can be used as a return value
     * from the block given to runTransactionBlock:
     */
    @objc class func successWithValue(_ value: MutableData) -> TransactionResult {
        TransactionResult(isSuccess: true, update: value)
    }

    /**
     * Used for runTransactionBlock:. Indicates that the current transaction should
     * no longer proceed.
     *
     * @return An FIRTransactionResult instance that can be used as a return value
     * from the block given to runTransactionBlock:
     */
    @objc class func abort() -> TransactionResult {
        .init(isSuccess: false, update: nil)
    }
}
