//
//  CatalogModel.swift
//  DDFReader
//
//  Created by Christopher Alford on 27/4/21.
//

import Foundation

// The class that represents a ISO 8211 Catalogue.

public class CatalogModel: ObservableObject {
    
    @Published var leaderData: Data = Data.init()
    
    var handle: FileHandle?
    var url: URL?
    var nFirstRecordOffset: UInt64 = 0
    
    var _interchangeLevel: byte?
    var _inlineCodeExtensionIndicator: byte?
    var _versionNumber: byte?
    var _appIndicator: byte? ;
    var _fieldControlLength: Int?
    var _extendedCharSet: String? // 4 characters
    
    var _recLength: Int?
    var _leaderIden: byte?
    var _fieldAreaStart: Int?
    var _sizeFieldLength: Int?
    var _sizeFieldPos: Int?
    var _sizeFieldTag: Int?
    
    var paoFieldDefns = [DDFFieldDefinition]() //DDFFieldDefinition
    var poRecord: DDFRecord?
    
    
    /// Open a ISO 8211 (DDF) file for reading, and read the DDR record
    /// to build the field definitions.
    ///
    /// Parameter - url: The url of the file to open.
    ///
    /// If the open succeeds the data descriptive record (DDR) will
    /// have been read, and all the field and subfield definitions will
    /// be available
    func open(url: URL) {
        self.url = url
        do {
            handle = try FileHandle.init(forReadingFrom: url)
            leaderData = handle!.readData(ofLength: DDF_LEADER_SIZE)
            //leaderData = handle!.readData(ofLength: 4096)
        } catch {
            print(error.localizedDescription)
        }
//        let content = String(bytes: leaderData, encoding: .utf8)
//        let breaks1E = content?.components(separatedBy: "\u{001E}")
//        for item in breaks1E! {
//            let printable = item.replacingOccurrences(of: "\u{001F}", with: "#")
//            print(printable)
//        }
//    }


        // Read the 24 byte leader.
        var achLeader = [byte] () //byte[DDF_LEADER_SIZE];

        if leaderData.count != DDF_LEADER_SIZE {
            #if DEBUG
            print("Catalog: Leader is short on DDF file \(url.lastPathComponent)")
            #endif
            destroy()
            return
        }
        achLeader = Array(leaderData)

        // Verify that this appears to be a valid DDF file.
        var bValid = true

        for i in 0..<DDF_LEADER_SIZE {
            //FIXME: Out of range here
            if achLeader[i] < 32 || achLeader[i] > 126 {
                bValid = false
            }
        }

        if achLeader[5] != "1".utf8.first && achLeader[5] != "2".utf8.first && achLeader[5] != "3".utf8.first {
            bValid = false
        }

        if achLeader[6] != "L".utf8.first {
            bValid = false
        }

        if achLeader[8] != "1".utf8.first && achLeader[8] != " ".utf8.first {
            bValid = false
        }

        // Extract information from leader.
        if bValid {
            _recLength = Int(DDFUtils.string(from: achLeader, start: 0, length: 5)!)!
            _interchangeLevel = achLeader[5]
            _leaderIden = achLeader[6]
            _inlineCodeExtensionIndicator = achLeader[7]
            _versionNumber = achLeader[8]
            _appIndicator = achLeader[9]
            _fieldControlLength = Int(DDFUtils.string(from: achLeader, start: 10, length: 2)!)!
            _fieldAreaStart = Int(DDFUtils.string(from: achLeader, start: 12, length: 5)!)!
            _extendedCharSet = String(bytes: [achLeader[17], 0, achLeader[18], 0, achLeader[19]], encoding: .utf8)!
            _sizeFieldLength = Int(DDFUtils.string(from: achLeader, start: 20, length: 1)!)!
            _sizeFieldPos = Int(DDFUtils.string(from: achLeader, start: 21, length: 1)!)!
            _sizeFieldTag = Int(DDFUtils.string(from: achLeader, start: 23, length: 1)!)!

            if (_recLength! < 12 || _fieldControlLength == 0 || _fieldAreaStart! < 24 || _sizeFieldLength == 0 || _sizeFieldPos == 0 || _sizeFieldTag == 0) {
                bValid = false
            }

            #if DEBUG
            print("bValid = \(bValid), from \(achLeader)")
            print(toString());
            #endif
        }

        // If the header is invalid, then clean up, report the error
        // and return.
        if (!bValid) {
            destroy();

            #if DEBUG
            print("CatalogModel: File \(url.lastPathComponent) does not appear to have a valid ISO 8211 header.")
            #endif
            return
        }

        #if DEBUG
        print("CatalogModel:  header parsed successfully");
        #endif

        /* -------------------------------------------------------------------- */
        /* Read the whole record into memory. */
        /* -------------------------------------------------------------------- */
        let data = handle!.readData(ofLength: _recLength!)
        achLeader = Array(data)

        var pachRecord = [byte]() // byte[_recLength];

        DDFUtils.arraycopy(source: achLeader,
                           sourceStart: 0,
                           destination: &pachRecord,
                           destinationStart: 0,
                           count: achLeader.count)
        let numNewRead = pachRecord.count - achLeader.count
        if self.read(toData: &pachRecord, offset: achLeader.count, length: numNewRead) != numNewRead {
            #if DEBUG
            print("CatalogModel: Header record is short on DDF file \(url.lastPathComponent)");
            #endif

            return
        }

        /* First make a pass counting the directory entries. */
        let nFieldEntryWidth = _sizeFieldLength! + _sizeFieldPos! + _sizeFieldTag!

        var nFieldDefnCount = 0;
        //for (i = DDF_LEADER_SIZE; i < _recLength; i += nFieldEntryWidth) {
        for i in stride(from: DDF_LEADER_SIZE, to: _recLength!, by: nFieldEntryWidth) {
            if pachRecord[i] == DDF_FIELD_TERMINATOR.utf8.first { // Index out of range
                break
            }

            nFieldDefnCount += 1
        }

        /* Allocate, and read field definitions. */
        paoFieldDefns = [DDFFieldDefinition]()

        for i in 0..<nFieldDefnCount {
            #if DEBUG
            print("CatalogModel.open: Reading field \(i)")
            #endif

            var szTag = [byte]() // byte[128];
            var nEntryOffset =  (i * nFieldEntryWidth) //FIXME: DDF_LEADER_SIZE +
            var nFieldLength: Int = 0
            var nFieldPos: Int = 0

            DDFUtils.arraycopy(source: pachRecord,
                               sourceStart: nEntryOffset,
                               destination: &szTag,
                               destinationStart: 0,
                               count: _sizeFieldTag!)

            nEntryOffset += _sizeFieldTag!
            if let value = DDFUtils.string(from: pachRecord, start: nEntryOffset, length: _sizeFieldLength!) {
            nFieldLength = Int(value)!
            } else {
                print("Invalid field length")
            }

            nEntryOffset += _sizeFieldLength!
            if let value = DDFUtils.string(from: pachRecord, start: nEntryOffset, length: _sizeFieldPos!) {
                nFieldPos = Int(value)!
            } else {
                print("Invalid field position")
            }

            var subPachRecord = [byte]() // byte[nFieldLength];
            DDFUtils.arraycopy(source: pachRecord,
                               sourceStart: _fieldAreaStart! + nFieldPos,
                               destination: &subPachRecord,
                               destinationStart: 0,
                               count: nFieldLength)

            paoFieldDefns.append(DDFFieldDefinition(poModuleIn: self,
                                                    pszTagIn: DDFUtils.string(from: szTag, start: 0, length: _sizeFieldTag!)!,
                                                    pachFieldArea: subPachRecord))
        }

        // Free the memory...
        achLeader.removeAll()
        pachRecord.removeAll()

        // Record the current file offset, the beginning of the first
        // data record.
        do {
            nFirstRecordOffset = try (handle?.offset())!
        } catch {
            print("File offset is not available!")
        }
    }

    /// Close an ISO 8211 file. Just close the file pointer to the file.
    public func close() {

        if (handle != nil) {
            do {
                try handle?.close()
            } catch {
                print("Failed to close Catalog file")
            }
            handle = nil
        }
    }

    /**
     * Clean up, get rid of data and close file pointer.
     */
    public func destroy() {
        close()

        // Cleanup the working record.
        poRecord = nil
        // Cleanup the field definitions.
        paoFieldDefns.removeAll()
    }

    /**
     * Write out module info to debugging file.
     *
     * A variety of information about the module is written to the
     * debugging file. This includes all the field and subfield
     * definitions read from the header.
     */
    public func toString() -> String {
        var buf = "CatalogModel:\n"
        buf.append("    _recLength = \(_recLength!)\n")
        buf.append("    _interchangeLevel = \(_interchangeLevel!)\n")
        buf.append("    _leaderIden = \(_leaderIden!)")
        buf.append("    _inlineCodeExtensionIndicator = \(_inlineCodeExtensionIndicator!)\n")
        buf.append("    _versionNumber = \(_versionNumber!)\n")
        buf.append("    _appIndicator = \(_appIndicator!)\n")
        buf.append("    _extendedCharSet = \(_extendedCharSet!)\n")
        buf.append("    _fieldControlLength = \(_fieldControlLength!)\n")
        buf.append("    _fieldAreaStart = \(_fieldAreaStart!)\n")
        buf.append("    _sizeFieldLength = \(_sizeFieldLength!)\n")
        buf.append("    _sizeFieldPos = \(_sizeFieldPos!)\n")
        buf.append("    _sizeFieldTag = \(_sizeFieldTag!)\n")
        return buf
    }

    public func dump() -> String {
        var buf = ""
        var iRecord = 0;
        repeat {
            if let poRecord = readRecord() {
                buf.append("  Record \(iRecord)(\(poRecord.getDataSize()) bytes)\n")
                iRecord += 1
                if poRecord.ddfFields.isEmpty == false {
                    for record in poRecord.ddfFields {
                        buf.append(record.toString()) // DDFField
                    }
                }
            } else {
                break
            }
        } while poRecord != nil
        return buf
    }


    /// Fetch the definition of the named field.
    ///
    /// - Parameter fieldName: The name of the field to search for. The
    ///        comparison is case insensitive.
    ///
    /// - Returns: A pointer to the request DDFFieldDefn object is
    ///         returned, or nil if none matching the name are found.
    ///         The return object remains owned by the CatalogModel, and
    ///         should not be deleted by application code.
    ///
    /// This function will scan the DDFFieldDefn's on this module, to
    /// find one with the indicated field name.
    ///
    public func findFieldDefn(fieldName: String) -> DDFFieldDefinition? {
        for fieldDefinition in paoFieldDefns {
            if fieldDefinition.name.equalsIgnoreCase(fieldName) {
                return fieldDefinition
            }
        }
        return nil
    }

    /**
     * Read one record from the file, and return to the application.
     * The returned record is owned by the module, and is reused from
     * call to call in order to preserve headers when they aren't
     * being re-read from record to record.
     *
     * @return A pointer to a DDFRecord object is returned, or nil if
     *         a read error, or end of file occurs. The returned
     *         record is owned by the module, and should not be
     *         deleted by the application. The record is only valid
     *         until the next ReadRecord() at which point it is
     *         overwritten.
     */
    public func readRecord() -> DDFRecord? {
        if (poRecord == nil) {
            poRecord = DDFRecord(poModuleIn: self)
        }

        if poRecord?.read() == true {
            return poRecord
        } else {
            return nil
        }
    }

    /**
     * Method for other components to call to get the CatalogModel to
     * read bytes into the provided array.
     *
     * @param toData the bytes to put data into.
     * @param offset the byte offset to start reading from, where ever
     *        the pointer currently is.
     * @param length the number of bytes to read.
     * @return the number of bytes read.
     */
    public func read(toData: inout [byte], offset: Int, length: Int) -> Int {
        if (handle == nil) {
            reopen();
        }

        if (handle != nil) {
            do {
                let currentOffset = try handle?.offset()
                if offset != 0 {
                    try handle!.seek(toOffset: currentOffset! + UInt64(offset))
                }
                if let data = try handle!.read(upToCount: length) {
                    toData = Array(data)
                    return toData.count
                }
            } catch {
                print("CatalogModel.read(): \(error.localizedDescription) reading from \(offset) to \(length) ")
                //into \(toData == nil ? "nil [byte]" : "byte[\(toData.count)]")
            }
        }
        return 0
    }

    /**
     * Convenience method to read a byte from the data file. Assumes
     * that you know what you are doing based on the parameters read
     * in the data file. For DDFFields that haven't loaded their
     * subfields.
     */
    public func read() -> Int {
        if (handle == nil) {
            reopen();
        }

        if (handle != nil) {
            do {
                let value = try handle!.read(upToCount: 1)
                let n = Array(value!).first
                return Int(n!)
            } catch {
                print("Catalog.read(): IOException caught");
            }
        }
        return 0;
    }

    /**
     * Convenience method to seek to a location in the data file.
     * Assumes that you know what you are doing based on the
     * parameters read in the data file. For DDFFields that haven't
     * loaded their subfields.
     *
     * @param pos the byte position to reposition the file pointer to.
     */
    public func seek(pos: UInt64) throws {
        if (handle == nil) {
            reopen()
        }

        if (handle != nil) {
            do {
                try handle?.seek(toOffset: pos)
            } catch {
                print("Error seeking to new position: \(error.localizedDescription)")
            }
        } else {
            print("Catalog doesn't have a pointer to a file")
        }
    }

    /**
     * Fetch a field definition by index.
     *
     * @param i (from 0 to GetFieldCount() - 1.
     * @return the returned field pointer or nil if the index is out
     *         of range.
     */
    public func getField(i: Int) -> DDFFieldDefinition? {
        if i >= 0 || i < paoFieldDefns.count {
            return paoFieldDefns[i] // (DDFFieldDefinition)
        }
        return nil
    }

    /**
     * Return to first record.
     *
     * The next call to ReadRecord() will read the first data record
     * in the file.
     *
     * @param nOffset the offset in the file to return to. By default
     *        this is -1, a special value indicating that reading
     *        should return to the first data record. Otherwise it is
     *        an absolute byte offset in the file.
     */
    public func rewind(nOffset: UInt64) throws {
        if (handle != nil) {
            do {
                try handle?.seek(toOffset: nOffset)
            } catch {
                print("Error rewinding file: \(error.localizedDescription)")
            }
            // Don't know what this has to do with anything...
            if (nOffset == nFirstRecordOffset && poRecord != nil) {
                poRecord?.clear()
            }
        }
    }

    public func rewindToFirst() throws {

        if (handle != nil) {
            do {
                try handle?.seek(toOffset: nFirstRecordOffset)
            } catch {
                print("Error rewinding file: \(error.localizedDescription)")
            }
        }

    }

    public func reopen() {
        do {
            if (handle == nil) {
                handle = try FileHandle.init(forReadingFrom: url!)
                leaderData = handle!.readData(ofLength: 24)
            }
        } catch {
            print(error.localizedDescription)
        }
    }
}
