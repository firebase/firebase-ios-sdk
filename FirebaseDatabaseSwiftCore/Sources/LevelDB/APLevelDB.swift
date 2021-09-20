/*
 * Copyright © 2014, codesplice pty ltd (sam@codesplice.com.au)
 *
 */

import leveldb
import Foundation

fileprivate class WriteBatch {
    let pointer: OpaquePointer

    fileprivate init() {
        pointer = leveldb_writebatch_create()
    }

    deinit {
        leveldb_writebatch_destroy(pointer)
    }

    fileprivate func put(_ key: Slice, value: Data?) {
        key.slice { (keyBytes, keyCount) in
            if let value = value {
                value.slice { (valueBytes, valueCount) in
                    leveldb_writebatch_put(pointer, keyBytes.baseAddress, keyCount, valueBytes.baseAddress, valueCount)
                }
            } else {
                leveldb_writebatch_put(pointer, keyBytes.baseAddress, keyCount, nil, 0)
            }
        }
    }

    fileprivate func delete(_ key: Slice) {
        key.slice { (keyBytes, keyCount) in
            leveldb_writebatch_delete(pointer, keyBytes.baseAddress, keyCount)
        }
    }

    fileprivate func clear() {
        leveldb_writebatch_clear(pointer)
    }
}

fileprivate struct SequenceQuery {
    let db: APLevelDB
    let startKey: Slice?
    let endKey: Slice?
    let descending: Bool
    let options: ReadOptions

    //
    init(db: APLevelDB,
         startKey: Slice? = nil,
         endKey: Slice? = nil,
         descending: Bool = false,
         options: [ReadOption] = ReadOption.standard) {

        self.db = db
        self.startKey = startKey
        self.endKey = endKey
        self.descending = descending
        self.options = ReadOptions(options: options)
    }
}

final fileprivate class DBIterator {
    private let db_pointer: OpaquePointer

    init(query: SequenceQuery) {
        db_pointer = leveldb_create_iterator(query.db.dbPointer, query.options.pointer)

        if let key = query.startKey {
            self.seek(key)
            if query.descending && self.isValid && query.db.compare(key, self.key!) == .orderedAscending {
                self.prevRow()
            }
        } else if query.descending {
            self.seekToLast()
        } else {
            self.seekToFirst()
        }
    }

    deinit {
        leveldb_iter_destroy(db_pointer)
    }

    var isValid: Bool {
        return leveldb_iter_valid(db_pointer) != 0
    }

    @discardableResult func seekToFirst() -> Bool {
        leveldb_iter_seek_to_first(db_pointer)
        return isValid
    }

    @discardableResult func seekToLast() -> Bool {
        leveldb_iter_seek_to_last(db_pointer)
        return isValid
    }

    @discardableResult func seek(_ key: Slice) -> Bool {
        key.slice { (keyBytes, keyCount) in
            leveldb_iter_seek(db_pointer, keyBytes.baseAddress, keyCount)
        }

        return isValid
    }

    @discardableResult func nextRow() -> Bool {
        leveldb_iter_next(db_pointer)
        return isValid
    }

    @discardableResult func prevRow() -> Bool {
        leveldb_iter_prev(db_pointer)
        return isValid
    }

    var key: Data? {
        var length: Int = 0
        let bytes = leveldb_iter_key(db_pointer, &length)
        guard length > 0 && bytes != nil else {
            return nil
        }

        return Data(bytes: bytes!, count: length)
    }

    var value: Data? {
        var length: Int = 0
        let bytes = leveldb_iter_value(db_pointer, &length)
        guard length > 0 && bytes != nil else {
            return nil
        }

        return Data(bytes: bytes!, count: length)
    }

    var error: String? {
        var error: UnsafeMutablePointer<Int8>? = nil
        leveldb_iter_get_error(db_pointer, &error)
        if error != nil {
            return String(cString: error!)
        } else {
            return nil
        }
    }

}

fileprivate class Snapshot {
    var pointer: OpaquePointer?
    var db: APLevelDB

    init(_ db: APLevelDB) {
        self.db = db
        pointer = leveldb_create_snapshot(db.dbPointer)
    }

    deinit {
        if pointer != nil {
            leveldb_release_snapshot(db.dbPointer, pointer)
        }
    }
}

fileprivate protocol Slice {
    func slice<ResultType>(_ f: (UnsafeBufferPointer<Int8>, Int) -> ResultType) -> ResultType
    func data() -> Data
}

extension Data: Slice {
    fileprivate func slice<ResultType>(_ f: (UnsafeBufferPointer<Int8>, Int) -> ResultType) -> ResultType {
        self.withUnsafeBytes {
            let unsafeBufferPointer = $0.bindMemory(to: Int8.self)
            return f(unsafeBufferPointer, self.count)
        }
    }

    fileprivate func data() -> Data {
        self
    }
}

extension String: Slice {
    fileprivate func slice<ResultType>(_ f: (UnsafeBufferPointer<Int8>, Int) -> ResultType) -> ResultType {
        return self.utf8CString.withUnsafeBufferPointer { a in
            f(a, Int(strlen(a.baseAddress!)))
        }
    }

    fileprivate func data() -> Data {
        self.utf8CString.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
    }
}

fileprivate enum ReadOption: Option {
    case verifyChecksums
    case fillCache
    case snapshot(Snapshot)

    func set(options: OpaquePointer) {
        switch self {
        case .verifyChecksums:
            leveldb_readoptions_set_verify_checksums(options, 1)
            break
        case .fillCache:
            leveldb_readoptions_set_fill_cache(options, 1)
            break
        case .snapshot(let snapshot):
            leveldb_readoptions_set_snapshot(options, snapshot.pointer)
            break
        }
    }

    static var standard: [ReadOption] {
        return [
            .fillCache,
        ]
    }
}

final fileprivate class ReadOptions: Options {
    fileprivate let pointer: OpaquePointer

    fileprivate init(options: [ReadOption]) {
        self.pointer = leveldb_readoptions_create()
        options.forEach { $0.set(options: pointer) }
    }

    deinit {
        leveldb_readoptions_destroy(pointer)
    }
}

public enum WriteOption: Option {
    case sync

    public func set(options: OpaquePointer) {
        switch self {
        case .sync:
            leveldb_writeoptions_set_sync(options, 1)
            break
        }
    }

    public static var standard: [WriteOption] {
        return []
    }
}

final public class WriteOptions: Options {
    public let pointer: OpaquePointer

    public init(options: [WriteOption]) {
        self.pointer = leveldb_writeoptions_create()
        options.forEach { $0.set(options: pointer) }
    }

    deinit {
        leveldb_writeoptions_destroy(pointer)
    }
}
@objc public class APLevelDBIterator: NSObject {
    private let iterator: DBIterator
    @objc public class func iterator(levelDB db: APLevelDB) -> APLevelDBIterator {
        APLevelDBIterator(levelDB: db)
    }
//
    // Designated initializer:
    @objc public init(levelDB db: APLevelDB) {
        self.iterator = DBIterator(query: SequenceQuery(db: db))
    }

    @objc public func seek(toKey key: String) -> Bool {
        iterator.seek(key)
    }

    @objc public func nextKey() -> String? {
        iterator.nextRow()
        guard iterator.isValid else { return nil }

        return iterator.key.flatMap { String(data: $0, encoding: .utf8) }
    }

    @objc public func key() -> String? {
        guard iterator.isValid else { return nil }
        return iterator.key.flatMap { String(data: $0, encoding: .utf8) }
    }

    @objc public func valueAsString() -> String? {
        iterator.value.flatMap { String(data: $0, encoding: .utf8) }
    }

    @objc public func valueAsData() -> Data? {
        iterator.value
    }
}

//@protocol APLevelDBWriteBatch <NSObject>
//
//- (void)setData:(NSData *)data forKey:(NSString *)key;
//- (void)setString:(NSString *)str forKey:(NSString *)key;
//
//- (void)removeKey:(NSString *)key;
//
//// Remove all of the buffered sets and removes:
//- (void)clear;
//- (BOOL)commit;
//
//@end

@objc public protocol APLevelDBWriteBatch: NSObjectProtocol {
    @objc func setData(_ data: Data, forKey key: String)
    @objc func setString(_ str: String, forKey key: String)
    @objc func removeKey(_ key: String)
    @objc func clear()
    @objc func commit() -> Bool

}

@objc public class APLevelDBWriteBatchImpl: NSObject, APLevelDBWriteBatch {
    fileprivate let batch: WriteBatch = WriteBatch()
    fileprivate let db: APLevelDB
    fileprivate init(db: APLevelDB) {
        self.db = db
    }
    @objc public func setData(_ data: Data, forKey key: String) {
        batch.put(key, value: data)
    }
    @objc public func setString(_ str: String, forKey key: String) {
        batch.put(key, value: str.data())
    }
    @objc public func removeKey(_ key: String) {
        batch.delete(key)
    }
    // Remove all of the buffered sets and removes:
    @objc public func clear() {
        batch.clear()
    }
    @objc public func commit() -> Bool {
        var error: UnsafeMutablePointer<Int8>? = nil

        let options = WriteOptions(options: WriteOption.standard)
        //
        leveldb_write(db.dbPointer, options.pointer, batch.pointer, &error)
        if error != nil {
            return false
//            throw LevelDBError.writeError(message: String(cString: error!))
        }
        return true
    }
}

public enum CompressionType: Int {
    case none = 0
    case snappy
}

public protocol Option {
    func set(options: OpaquePointer)

    static var standard: [Self] { get }
}

public protocol Options: AnyObject {
    associatedtype OptionType: Option

    init(options: [OptionType])

    var pointer: OpaquePointer { get }
}

public enum FileOption: Option {
    case createIfMissing
    case errorIfExists
    case paranoidChecks
    case writeBufferSize(Int)
    case maxOpenFiles(Int)
    case blockSize(Int)
    case blockRestartInterval(Int)
    case compression(CompressionType)

    public func set(options: OpaquePointer) {
        switch self {
        case .createIfMissing:
            leveldb_options_set_create_if_missing(options, 1)
            break
        case .errorIfExists:
            leveldb_options_set_error_if_exists(options, 1)
            break
        case .paranoidChecks:
            leveldb_options_set_paranoid_checks(options, 1)
            break
        case .writeBufferSize(let size):
            leveldb_options_set_write_buffer_size(options, Int(size))
            break
        case .maxOpenFiles(let files):
            leveldb_options_set_max_open_files(options, Int32(files))
            break
        case .blockSize(let size):
            leveldb_options_set_block_size(options, Int(size))
            break
        case .blockRestartInterval(let interval):
            leveldb_options_set_block_restart_interval(options, Int32(interval))
            break
        case .compression(let type):
            leveldb_options_set_compression(options, Int32(type.rawValue))
            break
        }
    }

    public static var standard: [FileOption] {
        return [
            .createIfMissing,
//            .writeBufferSize(1024 * 1024 * 4),
//            .maxOpenFiles(1000),
//            .blockSize(1024 * 4),
//            .blockRestartInterval(16),
//            .compression(.snappy)
        ]
    }
}

final public class FileOptions: Options {
    public let pointer: OpaquePointer

    public init(options: [FileOption]) {
        self.pointer = leveldb_options_create()
        options.forEach { $0.set(options: pointer) }
    }

    deinit {
        leveldb_options_destroy(pointer)
    }
}

public enum LevelDBError: Error {
    case undefinedError
    case openError(message: String)
    case destroyError(message: String)
    case repairError(message: String)
    case readError(message: String)
    case writeError(message: String)
}

fileprivate protocol Comparator {
    var name: String { get }
    func compare(_ a: Slice, _ b: Slice) -> ComparisonResult
}

/// A Swift implementation of the default LevelDB BytewiseComparator. Note this is not actually passed
/// to LevelDB, it's only used where needed from Swift code
final fileprivate class DefaultComparator: Comparator {
    var name: String { return "leveldb.BytewiseComparator" }
    func compare(_ a: Slice, _ b: Slice) -> ComparisonResult {
        // compare memory
        return a.slice { (aBytes: UnsafeBufferPointer<Int8>, aCount: Int) in
            return b.slice { (bBytes: UnsafeBufferPointer<Int8>, bCount: Int) in
                var cmp = memcmp(aBytes.baseAddress, bBytes.baseAddress, min(aCount, bCount))

                if cmp == 0 {
                    cmp = Int32(aCount - bCount)
                }

                return ComparisonResult(rawValue: (cmp < 0) ? -1 : (cmp > 0) ? 1 : 0)!
            }
        }
    }
}

@objc public class APLevelDB: NSObject {
    var dbPointer: OpaquePointer!
    fileprivate let comparator: Comparator

    @objc public class func levelDB(withPath path: String) throws -> APLevelDB {
        return try APLevelDB(path: path)
    }

    @objc public init(path: String) throws {
        var error: UnsafeMutablePointer<Int8>? = nil
        comparator = DefaultComparator()

        // open
        let options = FileOptions(options: FileOption.standard)
        let dbPointer = path.utf8CString.withUnsafeBufferPointer {
            return leveldb_open(options.pointer, $0.baseAddress!, &error)
        }

        // check if error
        guard let pointer = dbPointer else {
            if let error = error {
                throw LevelDBError.openError(message: String(cString: error))
            }

            throw LevelDBError.undefinedError
        }

        //
        self.dbPointer = pointer
//        Database(pointer, comparator: comparator)

    }
    deinit {
        close()
    }

    @objc public func close() {
        guard let pointer = dbPointer else { return }
        leveldb_close(pointer)
        dbPointer = nil
    }

    private func set(slice: Slice?, forKey key: String) -> Bool {
        var error: UnsafeMutablePointer<Int8>? = nil
        let options = WriteOptions(options: WriteOption.standard)

        key.slice { (keyBytes, keyCount) in

            if let value = slice {
                value.slice({ dataBytes, dataCount in
                    leveldb_put(dbPointer,
                                options.pointer,
                                keyBytes.baseAddress,
                                keyCount,
                                dataBytes.baseAddress,
                                dataCount,
                                &error)
                })
            } else {
                leveldb_put(dbPointer,
                            options.pointer,
                            keyBytes.baseAddress,
                            keyCount,
                            nil,
                            0,
                            &error)
            }
        }

        return error == nil
//        guard error == nil else {
//            throw LevelDBError.writeError(message: String(cString: error!))
//        }


        //    leveldb::Slice keySlice = SliceFromString(key);
        //    leveldb::Slice valueSlice = leveldb::Slice((const char *)[data bytes], (size_t)[data length]);
        //    leveldb::Status status = _db->Put(_writeOptions, keySlice, valueSlice);
        //    return (status.ok() == true);


    }

    @objc public func setData(_ data: Data?, forKey key: String) -> Bool {
        set(slice: data, forKey: key)
    }

    @objc public func setString(_ data: String?, forKey key: String) -> Bool {
        set(slice: data, forKey: key)
    }

    @objc public func removeKey(_ key: String) -> Bool {
        var error: UnsafeMutablePointer<Int8>? = nil
        let options = WriteOptions(options: WriteOption.standard)

        key.slice { (keyBytes, keyCount) in
            leveldb_delete(dbPointer,
                           options.pointer,
                           keyBytes.baseAddress,
                           keyCount,
                           &error)
        }
        return error == nil
    }

    @objc public func beginWriteBatch() -> APLevelDBWriteBatch {
        APLevelDBWriteBatchImpl(db: self)
    }

    @objc public func data(forKey key: String) -> Data? {
        var valueLength = 0
        var error: UnsafeMutablePointer<Int8>? = nil
        var value: UnsafeMutablePointer<Int8>? = nil

        let options = ReadOptions(options: ReadOption.standard)
        key.slice { (keyBytes, keyCount) in
            value = leveldb_get(dbPointer, options.pointer, keyBytes.baseAddress, keyCount, &valueLength, &error)
        }

        // throw if error
//        guard error == nil else {
//            throw LevelDBError.readError(message: String(cString: error!))
//        }

        // check fetch value lenght
        guard valueLength > 0 else {
            return nil
        }

        // create data
        return Data(bytes: value!, count: valueLength)
    }

    @objc public func string(forKey key: String) -> String? {
        data(forKey: key).flatMap { String(data: $0, encoding: .utf8) }
    }

    @objc public func allKeys() -> [String] {
        var keys: [String] = []
        enumerateKeys { key, _ in
            keys.append(key)
        }
        return keys
    }

    @objc public func enumerateKeys(_ block: @escaping (_ key: String, _ stop: UnsafeMutablePointer<ObjCBool>) -> Void) {
        enumerateKeys(withPrefix: "", usingBlock: block)
    }

    @objc public func enumerateKeys(withPrefix prefix: String, usingBlock block: @escaping (_ key: String, _ stop: UnsafeMutablePointer<ObjCBool>) -> Void) {
        var stop: ObjCBool = false
        let query = SequenceQuery(db: self, startKey: prefix)
        let iterator = DBIterator(query: query)

        while iterator.isValid {
            guard let keyData = iterator.key else { break }
            guard let key = String(data: keyData, encoding: .utf8) else { break }
            guard key.starts(with: prefix) else { break }

            block(key, &stop)

            guard !stop.boolValue, iterator.nextRow() else { break }
        }
    }

    @objc public func enumerateKeysAndValues(asStrings block: @escaping (_ key: String, _ value: String, _ stop: UnsafeMutablePointer<ObjCBool>) -> Void) {
        enumerateKeys(withPrefix: "", asStrings: block)
    }
    @objc public func enumerateKeys(withPrefix prefix: String, asStrings block: @escaping (_ key: String, _ value: String, _ stop: UnsafeMutablePointer<ObjCBool>) -> Void) {
        var stop: ObjCBool = false
        let query = SequenceQuery(db: self, startKey: prefix)
        let iterator = DBIterator(query: query)

        while iterator.isValid {
            guard let keyData = iterator.key, let data = iterator.value else { break }
            guard let key = String(data: keyData, encoding: .utf8) else { break }
            guard key.starts(with: prefix) else { break }
            guard let stringValue = String(data: data, encoding: .utf8) else { break }

            block(key, stringValue, &stop)

            guard !stop.boolValue, iterator.nextRow() else { break }
        }
    }

    @objc public func enumerateKeysAndValues(asData block: @escaping (_ key: String, _ value: Data, _ stop: UnsafeMutablePointer<ObjCBool>) -> Void) {
        enumerateKeys(withPrefix: "", asData: block)
    }

    @objc public func enumerateKeys(withPrefix prefix: String, asData block: @escaping (_ key: String, _ value: Data, _ stop: UnsafeMutablePointer<ObjCBool>) -> Void) {
        var stop: ObjCBool = false
        let query = SequenceQuery(db: self, startKey: prefix)
        let iterator = DBIterator(query: query)

        while iterator.isValid {
            guard let keyData = iterator.key, let data = iterator.value else { break }
            guard let key = String(data: keyData, encoding: .utf8) else { break }
            guard key.starts(with: prefix) else { break }

            block(key, data, &stop)

            guard !stop.boolValue, iterator.nextRow() else { break }
        }

    }

    @objc public func exactSize(from: String, to: String) -> Int {
        var size = 0
        let iterator = DBIterator(query: SequenceQuery(db: self, startKey: from, endKey: to, descending: false, options: ReadOption.standard))
        while iterator.isValid, let key = iterator.key, self.compare(key, to) != .orderedAscending {
            size += iterator.value?.count ?? 0
            iterator.nextRow()
        }
        return size
    }

    fileprivate func compare(_ a: Slice, _ b: Slice) -> ComparisonResult {
        comparator.compare(a, b)
    }
}
