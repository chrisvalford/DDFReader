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

    var paoFieldDefns: [DDFFieldDefinitions]? //DDFFieldDefinitions
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
        paoFieldDefns = nil
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
            if (Debug.debugging("iso8211")) {
                print("DDFModule: Leader is short on DDF file "
                        + pszFilename);
            }
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

        if achLeader[5] != "1" && achLeader[5] != "2" && achLeader[5] != "3" {
            bValid = false
        }

        if achLeader[6] != "L" {
            bValid = false
        }

        if achLeader[8] != "1" && achLeader[8] != " " {
            bValid = false
        }

        // Extract information from leader.
        if bValid {
            _recLength = Int(String(achLeader, 0, 5))
            _interchangeLevel = achLeader[5]
            _leaderIden = achLeader[6]
            _inlineCodeExtensionIndicator = achLeader[7]
            _versionNumber = achLeader[8]
            _appIndicator = achLeader[9]
            _fieldControlLength = Int(String(achLeader, 10, 2));
            _fieldAreaStart = Int(String(achLeader, 12, 5));
            _extendedCharSet = String(achLeader[17] + "" + achLeader[18] + "" + achLeader[19])
            _sizeFieldLength = Int(String(achLeader, 20, 1));
            _sizeFieldPos = Int(String(achLeader, 21, 1));
            _sizeFieldTag = Int(String(achLeader, 23, 1));

            if (_recLength < 12 || _fieldControlLength == 0 || _fieldAreaStart < 24 || _sizeFieldLength == 0 || _sizeFieldPos == 0 || _sizeFieldTag == 0) {
                bValid = false
            }

            if (Debug.debugging("iso8211")) {
                print("bValid = " + bValid + ", from " + String(achLeader));
                print(toString());
            }
        }

        // If the header is invalid, then clean up, report the error
        // and return.
        if (!bValid) {
            destroy();

            if Debug.debugging("iso8211") {
                print("DDFModule: File " + pszFilename
                        + " does not appear to have a valid ISO 8211 header.");
            }
            return nil;
        }

        if Debug.debugging("iso8211") {
            print("DDFModule:  header parsed successfully");

        }

        /* -------------------------------------------------------------------- */
        /* Read the whole record into memory. */
        /* -------------------------------------------------------------------- */
        var pachRecord = [byte]() // byte[_recLength];

        System.arraycopy(achLeader, 0, pachRecord, 0, achLeader.length);
       var numNewRead = pachRecord.length - achLeader.length;

        if (fpDDF.read(pachRecord, achLeader.length, numNewRead) != numNewRead) {
            if (Debug.debugging("iso8211")) {
                print("DDFModule: Header record is short on DDF file " + pszFilename);
            }

            return nil;
        }

        /* First make a pass counting the directory entries. */
       var nFieldEntryWidth = _sizeFieldLength + _sizeFieldPos + _sizeFieldTag;

       var nFieldDefnCount = 0;
        for (i = DDF_LEADER_SIZE; i < _recLength; i += nFieldEntryWidth) {
            if pachRecord[i] == DDF_FIELD_TERMINATOR {
                break
            }

            nFieldDefnCount += 1
        }

        /* Allocate, and read field definitions. */
        paoFieldDefns = [DDFFieldDefinition]()

        for i in 0..<nFieldDefnCount {
            if (Debug.debugging("iso8211")) {
                print("DDFModule.open: Reading field " + i)
            }

            var szTag = [byte]() // byte[128];
           var nEntryOffset = DDF_LEADER_SIZE + i * nFieldEntryWidth
            var nFieldLength: Int
            var nFieldPos: Int

            System.arraycopy(pachRecord, nEntryOffset, szTag, 0, _sizeFieldTag)

            nEntryOffset += _sizeFieldTag;
            nFieldLength = Int(String(pachRecord, nEntryOffset, _sizeFieldLength))

            nEntryOffset += _sizeFieldLength;
            nFieldPos = Int(new String(pachRecord, nEntryOffset, _sizeFieldPos))

            var subPachRecord = [byte]() // byte[nFieldLength];
            System.arraycopy(pachRecord,
                    _fieldAreaStart + nFieldPos,
                    subPachRecord,
                    0,
                    nFieldLength);

            paoFieldDefns.add(DDFFieldDefinition(self, String(szTag, 0, _sizeFieldTag), subPachRecord))
        }

        // Free the memory...
        achLeader = nil;
        pachRecord = nil;

        // Record the current file offset, the beginning of the first
        // data record.
        nFirstRecordOffset = fpDDF.getFilePointer()

        return fpDDF;
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
        buf.append("    _recLength = ")
        buf.append(_recLength)
        buf.append("\n");
        buf.append("    _interchangeLevel = ")
        buf.append(_interchangeLevel)
        buf.append("\n");
        buf.append("    _leaderIden = ")
        buf.append(_leaderIden)
        buf.append("\n");
        buf.append("    _inlineCodeExtensionIndicator = ")
        buf.append(_inlineCodeExtensionIndicator)
        buf.append("\n");
        buf.append("    _versionNumber = ")
        buf.append(_versionNumber)
        buf.append("\n");
        buf.append("    _appIndicator = ")
        buf.append(_appIndicator)
        buf.append("\n");
        buf.append("    _extendedCharSet = ")
        buf.append(_extendedCharSet)
        buf.append("\n");
        buf.append("    _fieldControlLength = ")
        buf.append(_fieldControlLength)
        buf.append("\n");
        buf.append("    _fieldAreaStart = ")
        buf.append(_fieldAreaStart)
        buf.append("\n");
        buf.append("    _sizeFieldLength = ")
        buf.append(_sizeFieldLength)
        buf.append("\n");
        buf.append("    _sizeFieldPos = ")
        buf.append(_sizeFieldPos)
        buf.append("\n");
        buf.append("    _sizeFieldTag = ")
        buf.append(_sizeFieldTag)
        buf.append("\n");
        return buf
    }

    public func dump() -> String {
        var buf = ""
        var poRecord: DDFRecord
       var iRecord = 0;
        repeat {
            poRecord = readRecord()
            buf.append("  Record ")
            buf.append((iRecord++))
            buf.append("(")
            buf.append(poRecord.getDataSize())
            buf.append(" bytes)\n");

            if poRecord.paoFields?.isEmpty == false {
                for record in poRecord.paoFields! {
                    buf.append(record.toString()) // DDFField
                }
            }
        } while poRecord != nil
        return buf
    }

    /**
     * Fetch the definition of the named field.
     *
     * This function will scan the DDFFieldDefn's on this module, to
     * find one with the indicated field name.
     *
     * @param pszFieldName The name of the field to search for. The
     *        comparison is case insensitive.
     *
     * @return A pointer to the request DDFFieldDefn object is
     *         returned, or nil if none matching the name are found.
     *         The return object remains owned by the DDFModule, and
     *         should not be deleted by application code.
     */
    public func findFieldDefn(pszFieldName: String) -> DDFFieldDefinition? {

        for (Iterator it = paoFieldDefns.iterator(); it.hasNext();) {
            DDFFieldDefinition ddffd = (DDFFieldDefinition) it.next();
            let pszThisName = ddffd.getName()

            if (Debug.debugging("iso8211detail")) {
                print("DDFModule.findFieldDefn(" + pszFieldName + ":"
                        + pszFieldName.length() + ") checking against ["
                        + pszThisName + ":" + pszThisName.length() + "]");
            }

            if (pszFieldName.equalsIgnoreCase(pszThisName)) {
                return ddffd;
            }
        }

        return nil;
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
            poRecord = DDFRecord(poModuleIn: self);
        }

        if (poRecord.read()) {
            return poRecord;
        } else {
            return nil;
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
                print("DDFModule.read(): "
                        + error.localizedDescription
                        + " reading from "
                        + offset
                        + " to "
                        + length
                        + " into "
                        + (toData == nil ? "nil [byte]" : "byte["
                                + toData.length + "]"));
                aioobe.printStackTrace();
            }
        }
        return 0;
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
            throw  IOException("DDFModule doesn't have a pointer to a file");
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
        if i >= 0 || i < paoFieldDefnscount {
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
        if (nOffset == -1) {
            nOffset = nFirstRecordOffset;
        }

        if (fpDDF != nil) {
            fpDDF.seek(nOffset);

            // Don't know what this has to do with anything...
            if (nOffset == nFirstRecordOffset && poRecord != nil) {
                poRecord.clear();
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
