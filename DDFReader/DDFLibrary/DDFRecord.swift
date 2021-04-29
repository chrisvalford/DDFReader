//
//  DDFRecord.swift
//  DDFReader
//
//  Created by Christopher Alford on 27/4/21.
//

import Foundation

/**
 * Contains instance data from one data record (DR). The data is
 * contained as a list of DDFField instances partitioning the raw data
 * into fields. Class contains one DR record from a file. We read into
 * the same record object repeatedly to ensure that repeated leaders
 * can be easily preserved.
 */
public class DDFRecord {

    var poModule: CatalogModel
    var nReuseHeader: Bool
    var nFieldOffset: Int // field data area, not dir entries.
    var nDataSize: Int // Whole record except leader with header
    var pachData: [byte]?

    var nFieldCount: Int
    var ddfFields = [DDFField]()

    var bIsClone: Bool = false

    public init(poModuleIn: CatalogModel) {
        poModule = poModuleIn
        nReuseHeader = false
        nFieldOffset = -1
        nDataSize = 0
        pachData = nil
        nFieldCount = 0
        bIsClone = false
    }

    /** Get the number of DDFFields on this record. */
    public func getFieldCount() -> Int {
        return nFieldCount;
    }

    /** Fetch size of records raw data (GetData()) in bytes. */
    public func getDataSize() -> Int {
        return nDataSize;
    }

    /**
     * Fetch the raw data for this record. The returned pointer is
     * effectively to the data for the first field of the record, and
     * is of size GetDataSize().
     */
    public func getData() -> [byte] {
        return pachData!
    }

    /**
     * Fetch the CatalogModel with which this record is associated.
     */
    public func getModule() -> CatalogModel {
        return poModule
    }

    /**
     * Write out record contents to debugging file.
     *
     * A variety of information about this record, and all it's fields
     * and subfields is written to the given debugging file handle.
     * Note that field definition information (ala DDFFieldDefn) isn't
     * written.
     */
    public func toString() -> String {
        var buf = "DDFRecord:\n"
        buf.append("    ReuseHeader = ")
        buf.append("\(nReuseHeader)")
        buf.append("\n");
        buf.append("    DataSize = ")
        buf.append("\(nDataSize)")
        buf.append("\n");
        for field in ddfFields {
            buf.append(field.toString()) //DDFField
        }

        return buf
    }

    /**
     * Read a record of data from the file, and parse the header to
     * build a field list for the record (or reuse the existing one if
     * reusing headers). It is expected that the file pointer will be
     * positioned at the beginning of a data record. It is the
     * CatalogModel's responsibility to do so.
     *
     * This method should only be called by the CatalogModel class.
     */
    func read() -> Bool {
        /* -------------------------------------------------------------------- */
        /* Redefine the record on the basis of the header if needed. */
        /*
         * As a side effect this will read the data for the record as
         * well.
         */
        /* -------------------------------------------------------------------- */
        if (!nReuseHeader) {
            print("iso8211", "DDFRecord reusing header, calling readHeader()")
            return readHeader();
        }

        /* -------------------------------------------------------------------- */
        /* Otherwise we read just the data and carefully overlay it on */
        /*
         * the previous records data without disturbing the rest of
         * the
         */
        /* record. */
        /* -------------------------------------------------------------------- */

       var tempData =  [byte]() // byte[nDataSize - nFieldOffset];
        var nReadBytes = poModule.read(toData: tempData, offset: 0, length: tempData.count)
        DDFUtils.arraycopy(source: pachData!,
                           sourceStart: nFieldOffset,
                           destination: &tempData,
                           destinationStart: 0,
                           count: tempData.count)

        if nReadBytes != (nDataSize - nFieldOffset) && nReadBytes == -1 {
            return false
        } else if nReadBytes != (nDataSize - nFieldOffset) {
            print("DDFRecord: Data record is short on DDF file.");
            return false
        }
        // notdef: eventually we may have to do something at this
        // point to
        // notify the DDFField's that their data values have changed.
        return true
    }

    /**
     * Clear any information associated with the last header in
     * preparation for reading a new header.
     */
    public func clear() {
        ddfFields.removeAll()
        nFieldCount = 0
        pachData?.removeAll()
        nDataSize = 0
        nReuseHeader = false
    }

    /**
     * This perform the header reading and parsing job for the read()
     * method. It reads the header, and builds a field list.
     */
    func readHeader() -> Bool {

        /* -------------------------------------------------------------------- */
        /* Clear any existing information. */
        /* -------------------------------------------------------------------- */
        clear()

        /* -------------------------------------------------------------------- */
        /* Read the 24 byte leader. */
        /* -------------------------------------------------------------------- */
        var achLeader = [byte]() //byte[DDF_LEADER_SIZE];

        var nReadBytes = poModule.read(toData: achLeader, offset: 0, length: DDF_LEADER_SIZE)
        if nReadBytes == -1 {
            return false
        } else if nReadBytes != DDF_LEADER_SIZE {
            print("DDFRecord.readHeader(): Leader is short on DDF file.");
            return false
        }

        /* -------------------------------------------------------------------- */
        /* Extract information from leader. */
        /* -------------------------------------------------------------------- */
        var _recLength: Int
        var _fieldAreaStart: Int
        var _sizeFieldLength: Int
        var _sizeFieldPos: Int
        var _sizeFieldTag: Int
        var _leaderIden: byte

        if let recLength = DDFUtils.string(from: achLeader, start: 0, length: 5), let fieldAreaStart = DDFUtils.string(from: achLeader, start: 12, length: 5) {
            _recLength = Int(recLength)!
            _fieldAreaStart = Int(fieldAreaStart)!
            print("Finished reading headers")
        } else {
            // Turns out, this usually indicates the end of the header
            // information,
            // with "^^^^^^^" being in the file. This is filler.
            #if DEBUG
            print("DDFRecord.readHeader(): failed")
            print("Data record appears to be corrupt on DDF file.\n -- ensure that the files were uncompressed without modifying\n carriage return/linefeeds (by default WINZIP does this).")
            #endif
            return false
        }

        _leaderIden = achLeader[6];
        _sizeFieldLength = Int(achLeader[20] - UInt8(48)) // ASCII 0
        _sizeFieldPos = Int(achLeader[21] - UInt8(48)) // ASCII 0
        _sizeFieldTag = Int(achLeader[23] - UInt8(48)) // ASCII 0

        if (_leaderIden == "R".utf8.first) {
            nReuseHeader = true;
        }

        nFieldOffset = _fieldAreaStart - DDF_LEADER_SIZE;

        #if DEBUG
            print("\trecord length [0,5] = \(_recLength)")
            print("\tfield area start [12,5]= \(_fieldAreaStart)")
            print("\tleader id [6] = \(_leaderIden), reuse header = \(nReuseHeader)")
            print("\tfield length [20] = \(_sizeFieldLength)")
            print("\tfield position [21] = \(_sizeFieldPos)")
            print("\tfield tag [23] = \(_sizeFieldTag)")
        #endif

        var readSubfields = false

        /* -------------------------------------------------------------------- */
        /* Is there anything seemly screwy about this record? */
        /* -------------------------------------------------------------------- */
        if _recLength == 0 {
            // Looks like for record lengths of zero, we really want
            // to consult the size of the fields before we try to read
            // in all of the data for this record. Most likely, we
            // don't, and want to access the data later only when we
            // need it.

            nDataSize = _fieldAreaStart - DDF_LEADER_SIZE;
        } else if _recLength < 24 || _recLength > 100000000 || _fieldAreaStart < 24 || _fieldAreaStart > 100000 {
            print("DDFRecord: Data record appears to be corrupt on DDF file.\n -- ensure that the files were uncompressed without modifying\n carriage return/linefeeds (by default WINZIP does this).");
            return false
        } else {
            /* -------------------------------------------------------------------- */
            /* Read the remainder of the record. */
            /* -------------------------------------------------------------------- */
            nDataSize = _recLength - DDF_LEADER_SIZE;
            readSubfields = true;
        }

        pachData = [byte]() // byte[nDataSize];

        if (poModule.read(toData: pachData!, offset: 0, length: nDataSize) != nDataSize) {
            print("DDFRecord: Data record is short on DDF file.");
            return false;
        }

        /* -------------------------------------------------------------------- */
        /*
         * Loop over the directory entries, making a pass counting
         * them.
         */
        /* -------------------------------------------------------------------- */
        var i: Int
        var nFieldEntryWidth: Int

        nFieldEntryWidth = _sizeFieldLength + _sizeFieldPos + _sizeFieldTag
        nFieldCount = 0
        for i in stride(from: 0, to: nDataSize, by: nFieldEntryWidth) {
        //for (i = 0; i < nDataSize; i += nFieldEntryWidth) {
            if pachData![i] == DDF_FIELD_TERMINATOR.asciiValue {
                break
            }
            nFieldCount += 1
        }

        /* ==================================================================== */
        /* Allocate, and read field definitions. */
        /* ==================================================================== */
        ddfFields = [DDFField]() //Vector(nFieldCount);

        for i in 0..<nFieldCount {
            var szTag: String
            var nEntryOffset = i * nFieldEntryWidth;
            var nFieldLength: Int
            var nFieldPos: Int

            /* -------------------------------------------------------------------- */
            /* Read the position information and tag. */
            /* -------------------------------------------------------------------- */
            szTag = DDFUtils.string(from: pachData!, start: nEntryOffset, length: _sizeFieldTag)!

            nEntryOffset += _sizeFieldTag
            nFieldLength = Int(DDFUtils.string(from: pachData!, start: nEntryOffset, length: _sizeFieldLength)!)!
            nEntryOffset += _sizeFieldLength
            nFieldPos = Int(DDFUtils.string(from: pachData!, start: nEntryOffset, length: _sizeFieldPos)!)!

            /* -------------------------------------------------------------------- */
            /* Find the corresponding field in the module directory. */
            /* -------------------------------------------------------------------- */
            let poFieldDefn = poModule.findFieldDefn(fieldName: szTag) // DDFFieldDefinition

            if (poFieldDefn == nil) {
                print("DDFRecord: Undefined field " + szTag + " encountered in data record.");
                return false;
            }

            var ddff: DDFField

            if (readSubfields) {

                /* -------------------------------------------------------------------- */
                /* Assign info the DDFField. */
                /* -------------------------------------------------------------------- */
                var tempData = [byte]() //byte[nFieldLength];
                DDFUtils.arraycopy(source: pachData!,
                                   sourceStart: _fieldAreaStart + nFieldPos - DDF_LEADER_SIZE,
                                   destination: &tempData,
                                   destinationStart: 0,
                                   count: tempData.count)

                ddff = DDFField(poDefnIn: poFieldDefn!, pachDataIn: tempData, doSubfields: readSubfields)

            } else {
                // Save the info for reading later directly out of the field.
                ddff = DDFField(poDefnIn: poFieldDefn!, dataPositionIn: nFieldPos, dataLengthIn: nFieldLength)
                ddff.setHeaderOffset(headerOffsetIn: poModule._recLength + _fieldAreaStart)
            }
            ddfFields.append(ddff)
        }

        return true
    }


    /// Find the named field within this record.
    ///
    /// Parameter - pszName The name of the field to fetch. The comparison is case insensitive.
    /// - Parameter iFieldIndex: The instance of this field to fetch. Use
    ///        zero (the default) for the first instance.
    ///
    /// - Returns: Pointer to the requested DDFField. This pointer is to
    ///         an internal object, and should not be freed. It remains
    ///         valid until the next record read.
    ///
    public func findField(pszName: String) -> DDFField? {
        guard ddfFields.isEmpty == false else { return nil }
        
        for ddfField in ddfFields {
            if pszName.equalsIgnoreCase(ddfField.definition.name) {
//                if (iFieldIndex == 0) {
                    return ddfField;
//                } else {
//                    iFieldIndex -= 1
//                }
            }
        }
    }

    /**
     * Fetch field object based on index.
     *
     * @param i The index of the field to fetch. Between 0 and
     *        GetFieldCount()-1.
     *
     * @return A DDFField pointer, or nil if the index is out of
     *         range.
     */
    public func getField(i: Int) -> DDFField? {
        if i < 0 || i > ddfFields.count {
            return nil
        }
        return ddfFields[i] // (DDFField)
    }

    /**
     * Get an iterator over the fields.
     */
//    public func iterator() -> Iterator {
//        if (ddfFields != nil) {
//            return ddfFields.iterator();
//        }
//        return nil;
//    }

    /**
     * Fetch value of a subfield as an integer. This is a convenience
     * function for fetching a subfield of a field within this record.
     *
     * @param pszField The name of the field containing the subfield.
     * @param iFieldIndex The instance of this field within the
     *        record. Use zero for the first instance of this field.
     * @param pszSubfield The name of the subfield within the selected
     *        field.
     * @param iSubfieldIndex The instance of this subfield within the
     *        record. Use zero for the first instance.
     * @return The value of the subfield, or zero if it failed for
     *         some reason.
     */
    public func getIntSubfield(pszField: String, iFieldIndex: Int, pszSubfield: String, iSubfieldIndex: inout Int) -> Int? {
        
        guard let poField = findField(pszName: pszField) else { return nil }

        /* -------------------------------------------------------------------- */
        /* Get the subfield definition */
        /* -------------------------------------------------------------------- */

        let poSFDefn = poField.definition.findSubfieldDefinition(named: pszSubfield) // DDFSubfieldDefinition
        if (poSFDefn == nil) {
            return 0
        }

        /* -------------------------------------------------------------------- */
        /* Get a pointer to the data. */
        /* -------------------------------------------------------------------- */
        var nBytesRemaining: Int? = 0
        var pachData: [byte] = poField.getSubfieldData(poSFDefn: poSFDefn, pnMaxBytes: &nBytesRemaining, iSubfieldIndex: &iSubfieldIndex)!

        /* -------------------------------------------------------------------- */
        /* Return the extracted value. */
        /* -------------------------------------------------------------------- */

        return poSFDefn?.extractIntData(pachSourceData: pachData, nMaxBytes: nBytesRemaining!, pnConsumedBytes: nil)
    }

    /**
     * Fetch value of a subfield as a float (double). This is a
     * convenience function for fetching a subfield of a field within
     * this record.
     *
     * @param pszField The name of the field containing the subfield.
     * @param iFieldIndex The instance of this field within the
     *        record. Use zero for the first instance of this field.
     * @param pszSubfield The name of the subfield within the selected
     *        field.
     * @param iSubfieldIndex The instance of this subfield within the
     *        record. Use zero for the first instance.
     * @return The value of the subfield, or zero if it failed for
     *         some reason.
     */
    public func getFloatSubfield(pszField: String, iFieldIndex: Int, pszSubfield: String, iSubfieldIndex: Int) -> Double? {
        
        guard let poField = findField(pszName: pszField) else { return nil }

        /* -------------------------------------------------------------------- */
        /* Get the subfield definition */
        /* -------------------------------------------------------------------- */
        let poSFDefn = poField.definition.findSubfieldDefinition(named: pszSubfield)
        if (poSFDefn == nil) {
            return 0;
        }

        /* -------------------------------------------------------------------- */
        /* Get a pointer to the data. */
        /* -------------------------------------------------------------------- */
        var nBytesRemaining: Int
        var pachData: [byte] = poField.getSubfieldData(poSFDefn: poSFDefn, pnMaxBytes: &nBytesRemaining, iSubfieldIndex: iSubfieldIndex)!

        /* -------------------------------------------------------------------- */
        /* Return the extracted value. */
        /* -------------------------------------------------------------------- */
        return poSFDefn!.extractFloatData(pachSourceData: pachData, nMaxBytes: nBytesRemaining, pnConsumedBytes: nil)
    }

    /**
     * Fetch value of a subfield as a string. This is a convenience
     * function for fetching a subfield of a field within this record.
     *
     * @param pszField The name of the field containing the subfield.
     * @param iFieldIndex The instance of this field within the
     *        record. Use zero for the first instance of this field.
     * @param pszSubfield The name of the subfield within the selected
     *        field.
     * @param iSubfieldIndex The instance of this subfield within the
     *        record. Use zero for the first instance.
     * @return The value of the subfield, or nil if it failed for
     *         some reason. The returned pointer is to internal data
     *         and should not be modified or freed by the application.
     */

    func getStringSubfield(pszField: String, iFieldIndex: Int, pszSubfield: String, iSubfieldIndex: Int) -> String? {

        guard let poField = findField(pszName: pszField) else { return nil }

        /* -------------------------------------------------------------------- */
        /* Get the subfield definition */
        /* -------------------------------------------------------------------- */
        var poSFDefn = poField.definition.findSubfieldDefinition(named: pszSubfield) // DDFSubfieldDefinition
        if poSFDefn == nil {
            return nil
        }

        /* -------------------------------------------------------------------- */
        /* Get a pointer to the data. */
        /* -------------------------------------------------------------------- */
        var nBytesRemaining: Int?

        let pachData: [byte] = poField.getSubfieldData(poSFDefn: poSFDefn, pnMaxBytes: &nBytesRemaining, iSubfieldIndex: iSubfieldIndex)!;

        /* -------------------------------------------------------------------- */
        /* Return the extracted value. */
        /* -------------------------------------------------------------------- */

        return poSFDefn!.extractStringData(pachSourceData: pachData, nMaxBytes: nBytesRemaining!, pnConsumedBytes: nil);
    }

}
