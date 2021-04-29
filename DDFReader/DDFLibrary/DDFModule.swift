//
//  DDFModule.swift
//  DDFReader
//
//  Created by Christopher Alford on 27/4/21.
//

import Foundation

/**
 * The class that represents a ISO 8211 file.
 */
public class DDFModule {

    var fpDDF: BinaryFile?
    var fileName: String
    var nFirstRecordOffset: Int64

    var _interchangeLevel: byte ;
    var _inlineCodeExtensionIndicator: byte ;
    var _versionNumber: byte ;
    var _appIndicator: byte ;
    var _fieldControlLength: Int
    var _extendedCharSet: String // 4 characters

    var _recLength: Int
    var _leaderIden: byte
    var _fieldAreaStart: Int
    var _sizeFieldLength: Int
    var _sizeFieldPos: Int
    var _sizeFieldTag: Int

    var paoFieldDefns = [DDFFieldDefinition]() //DDFFieldDefinition
    var poRecord: DDFRecord?

    /**
     * The constructor. Need to call open() if this constructor is
     * used.
     */
    public init() {}

    public init(ddfName: String) {
        open(ddfName)
    }

    /**
     * Close an ISO 8211 file. Just close the file pointer to the
     * file.
     */
    public func close() {

        if (fpDDF != nil) {
            do {
                try fpDDF.close();
            } catch {
                print("DDFModule IOException when closing DDFModule file")
            }
            fpDDF = nil
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
     * Open a ISO 8211 (DDF) file for reading, and read the DDR record
     * to build the field definitions.
     *
     * If the open succeeds the data descriptive record (DDR) will
     * have been read, and all the field and subfield definitions will
     * be available.
     *
     * @param pszFilename The name of the file to open.
     */
    public func open(pszFilename: String) -> BinaryFile {

        fileName = pszFilename;

        fpDDF = BinaryBufferedFile(pszFilename);

        // Read the 24 byte leader.
        var achLeader = [byte] () //byte[DDF_LEADER_SIZE];

        if fpDDF.read(achLeader) != DDF_LEADER_SIZE {
            destroy();
            #if DEBUG
                print("DDFModule: Leader is short on DDF file "
                        + pszFilename);
            #endif
            return nil;
        }

        // Verify that this appears to be a valid DDF file.
        var i: Int
        var bValid = true

        for i in 0..<DDF_LEADER_SIZE {
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

            if (_recLength < 12 || _fieldControlLength == 0 || _fieldAreaStart < 24 || _sizeFieldLength == 0 || _sizeFieldPos == 0 || _sizeFieldTag == 0) {
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
            print("DDFModule: File " + pszFilename + " does not appear to have a valid ISO 8211 header.");
            #endif
            return nil
        }

        #if DEBUG
        print("DDFModule:  header parsed successfully");
        #endif

        /* -------------------------------------------------------------------- */
        /* Read the whole record into memory. */
        /* -------------------------------------------------------------------- */
        var pachRecord = [byte]() // byte[_recLength];

        DDFUtils.arraycopy(source: achLeader,
                           sourceStart: 0,
                           destination: &pachRecord,
                           destinationStart: 0,
                           count: achLeader.count)
       var numNewRead = pachRecord.count - achLeader.count

        if fpDDF.read(pachRecord, achLeader.count, numNewRead) != numNewRead {
            #if DEBUG
            print("DDFModule: Header record is short on DDF file " + pszFilename);
            #endif

            return nil;
        }

        /* First make a pass counting the directory entries. */
       var nFieldEntryWidth = _sizeFieldLength + _sizeFieldPos + _sizeFieldTag;

       var nFieldDefnCount = 0;
        //for (i = DDF_LEADER_SIZE; i < _recLength; i += nFieldEntryWidth) {
        for i in stride(from: DDF_LEADER_SIZE, to: _recLength, by: nFieldEntryWidth) {
            if pachRecord[i] == DDF_FIELD_TERMINATOR.utf8.first {
                break
            }

            nFieldDefnCount += 1
        }

        /* Allocate, and read field definitions. */
        paoFieldDefns = [DDFFieldDefinition]()

        for i in 0..<nFieldDefnCount {
            #if DEBUG
                print("DDFModule.open: Reading field \(i)")
            #endif

            var szTag = [byte]() // byte[128];
           var nEntryOffset = DDF_LEADER_SIZE + i * nFieldEntryWidth
            var nFieldLength: Int
            var nFieldPos: Int

            DDFUtils.arraycopy(source: pachRecord,
                               sourceStart: nEntryOffset,
                               destination: &szTag,
                               destinationStart: 0,
                               count: _sizeFieldTag)

            nEntryOffset += _sizeFieldTag;
            nFieldLength = Int(DDFUtils.string(from: pachRecord, start: nEntryOffset, length: _sizeFieldLength)!)!

            nEntryOffset += _sizeFieldLength
            nFieldPos = Int(DDFUtils.string(from: pachRecord, start: nEntryOffset, length: _sizeFieldPos)!)!

            var subPachRecord = [byte]() // byte[nFieldLength];
            DDFUtils.arraycopy(source: pachRecord,
                               sourceStart: _fieldAreaStart + nFieldPos,
                               destination: &subPachRecord,
                               destinationStart: 0,
                               count: nFieldLength)

            paoFieldDefns.append(DDFFieldDefinition(poModuleIn: self,
                                                    pszTagIn: DDFUtils.string(from: szTag, start: 0, length: _sizeFieldTag)!,
                                                    pachFieldArea: subPachRecord))
        }

        // Free the memory...
        achLeader.removeAll()
        pachRecord.removeAll()

        // Record the current file offset, the beginning of the first
        // data record.
        nFirstRecordOffset = fpDDF.getFilePointer()

        return fpDDF
    }

    /**
     * Write out module info to debugging file.
     *
     * A variety of information about the module is written to the
     * debugging file. This includes all the field and subfield
     * definitions read from the header.
     */
    public func toString() -> String {
        var buf = "DDFModule:\n"
        buf.append("    _recLength = \(_recLength)\n")
        buf.append("    _interchangeLevel = \(_interchangeLevel)\n")
        buf.append("    _leaderIden = \(_leaderIden)")
        buf.append("    _inlineCodeExtensionIndicator = \(_inlineCodeExtensionIndicator)\n")
        buf.append("    _versionNumber = \(_versionNumber)\n")
        buf.append("    _appIndicator = \(_appIndicator)\n")
        buf.append("    _extendedCharSet = \(_extendedCharSet)\n")
        buf.append("    _fieldControlLength = \(_fieldControlLength)\n")
        buf.append("    _fieldAreaStart = \(_fieldAreaStart)\n")
        buf.append("    _sizeFieldLength = \(_sizeFieldLength)\n")
        buf.append("    _sizeFieldPos = \(_sizeFieldPos)\n")
        buf.append("    _sizeFieldTag = \(_sizeFieldTag)\n")
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
     ///         The return object remains owned by the DDFModule, and
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

        if poRecord?.read() {
            return poRecord
        } else {
            return nil
        }
    }

    /**
     * Method for other components to call to get the DDFModule to
     * read bytes into the provided array.
     *
     * @param toData the bytes to put data into.
     * @param offset the byte offset to start reading from, whereever
     *        the pointer currently is.
     * @param length the number of bytes to read.
     * @return the number of bytes read.
     */
    public func read(toData: [byte], offset: Int, length: Int) -> Int {
        if (fpDDF == nil) {
            reopen();
        }

        if (fpDDF != nil) {
            do {
                return fpDDF.read(toData, offset, length);
            } catch {
                print("DDFModule.read(): \(error.localizedDescription) reading from \(offset) to \(length) ")
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
        if (fpDDF == nil) {
            reopen();
        }

        if (fpDDF != nil) {
            do {
                return fpDDF.read();
            } catch {
                print("DDFModule.read(): IOException caught");
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
    public func seek(pos: Int64) throws {
        if (fpDDF == nil) {
            reopen();
        }

        if (fpDDF != nil) {
            fpDDF.seek(pos);
        } else {
            print("DDFModule doesn't have a pointer to a file")
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
    public func rewind(nOffset: Int64) throws {
        var offset = nOffset
        if (offset == -1) {
            offset = nFirstRecordOffset;
        }

        if (fpDDF != nil) {
            fpDDF.seek(offset);

            // Don't know what this has to do with anything...
            if (offset == nFirstRecordOffset && poRecord != nil) {
                poRecord?.clear()
            }
        }

    }

    public func reopen() {
        do {
            if (fpDDF == nil) {
                fpDDF = BinaryBufferedFile(fileName)
            }
        } catch {

        }
    }
}
