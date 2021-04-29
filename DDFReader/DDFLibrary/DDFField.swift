//
//  DDFField.swift
//  DDFReader
//
//  Created by Christopher Alford on 27/4/21.
//

import Foundation


/// This object represents one field in a DDFRecord. This models an
/// instance of the fields data, rather than it's data definition which
/// is handled by the DDFFieldDefn class.
///
/// Note that a DDFField doesn't  have DDFSubfield children as you would expect.
/// To extract subfield values use
/// GetSubfieldData() to find the right data pointer
/// and then use
/// ExtractIntData(), ExtractFloatData() or  ExtractStringData().

public class DDFField {

    private (set) var definition: DDFFieldDefinition
    var pachData: [UInt8]?
    var subfields: Hashtable
    var dataPosition: Int
    var dataLength: Int
    var headerOffset: Int

    public init() {}

    public init(poDefnIn: DDFFieldDefinition, dataPositionIn: Int, dataLengthIn: Int) {
        initialize(poDefnIn, nil);
        dataPosition = dataPositionIn;
        dataLength = dataLengthIn;
    }

    public convenience init(poDefnIn: DDFFieldDefinition, pachDataIn: [byte]) {
        self.init(poDefnIn: poDefnIn, pachDataIn: pachDataIn, doSubfields: true)
    }

    public init(poDefnIn: DDFFieldDefinition, pachDataIn: [byte], doSubfields: Bool) {
        initialize(poDefnIn: poDefnIn, pachDataIn: pachDataIn)
        if (doSubfields) {
            buildSubfields();
        }
    }

    public func initialize(poDefnIn: DDFFieldDefinition, pachDataIn: [byte]) {
        pachData = pachDataIn;
        definition = poDefnIn;
        subfields = Hashtable();
    }

    /// Set how many bytes to add to the data position for absolute
    /// position in the data file for the field data.
    ///
    /// - Parameter headerOffsetIn: offset to set
    func setHeaderOffset(headerOffsetIn: Int) {
        headerOffset = headerOffsetIn;
    }

    /// Get how many bytes to add to the data position for absolute
    /// position in the data file for the field data.
    ///
    /// - Returns:The current offset
    public func getHeaderOffset() -> Int {
        return headerOffset;
    }


    /// Return the pointer to the entire data block for this record.
    /// This is an internal copy, and shouldn't be freed by the
    /// application. If nil, then check the dataPosition and
    /// dataLength for byte offsets for the data in the file, and go
    /// get it yourself. This is done for really large files where it
    /// doesn't make sense to load the data.
    ///
    /// - Returns: The data block
    public func getData() -> [byte] {
        return pachData!
    }

    /// The size of the data
    /// - Returns: Number of bytes in the data block
    public func getDataSize() -> Int {
        if (pachData != nil) {
            return pachData!.count
        } else {
            return 0
        }
    }

    /// If getData() returns nil, it'll be your responsibilty to go
    /// after the data you need for this field.
    ///
    /// - Returns the byte offset into the source file to start reading this field
    public func getDataPosition() -> Int {
        return dataPosition;
    }

    /// If getData() returns nil, it'll be your responsibilty to go
    /// after the data you need for this field.
    ///
    /// - Returns: the number of bytes contained in the source file for this field
    public func getDataLength() -> Int {
        return dataLength;
    }

    /// Creates a string with variety of information about this field,
    /// and all it's subfields is written to the given debugging file
    /// handle. Note that field definition information (ala
    /// DDFFieldDefn) isn't written.
    ///
    /// - Returns: String containing info.
    public func toString() -> String {
        var buf = "  DDFField:\n"
        buf.append("\tTag = ")
        buf.append(definition.name)
        buf.append("\n");
        buf.append("\tDescription = ")
        buf.append(definition.getDescription())
        buf.append("\n");
        let size = getDataSize();
        buf.append("\tDataSize = ")
        buf.append("\(size)")
        buf.append("\n");

        if (pachData == nil) {
            buf.append("\tHeader offset = ")
            buf.append("\(headerOffset)")
            buf.append("\n");
            buf.append("\tData position = ")
            buf.append("\(dataPosition)")
            buf.append("\n");
            buf.append("\tData length = ")
            buf.append("\(dataLength)")
            buf.append("\n");
            return buf
        }

        buf.append("\tData = ");
        for i in 0..<min(size, 40) {
            if pachData![i] < 32 || pachData![i] > 126 {
                buf.append(" | ")
                buf.append(Character(UnicodeScalar(pachData![i])))
            } else {
                buf.append(Character(UnicodeScalar(pachData![i])))
            }
        }

        if (size > 40) {
            buf.append("...")
        }
        buf.append("\n")

        /* -------------------------------------------------------------------- */
        /* dump the data of the subfields. */
        /* -------------------------------------------------------------------- */
        #if DEBUG
        var iOffset = 0;
        var nBytesConsumed: Int? //= 0
        
        for nLoopCount in 0..<getRepeatCount() {
            if (nLoopCount > 8) {
                buf.append("      ...\n");
                break;
            }
            
            for i in 0..<definition.getSubfieldCount() {
                var subPachData = [byte]() // byte[pachData.length - iOffset];
                DDFUtils.arraycopy(source: pachData!,
                                   sourceStart: iOffset,
                                   destination: &subPachData,
                                   destinationStart: 0,
                                   count: subPachData.count)
                
                buf.append(definition.getSubfieldDefn(i: i)!.dumpData(pachData: subPachData,
                                                                   nMaxBytes: subPachData.count))
                
                definition.getSubfieldDefn(i: i)!.getDataLength(pachSourceData: subPachData,
                                                           nMaxBytes: subPachData.count,
                                                           pnConsumedBytes: &nBytesConsumed);
                iOffset += nBytesConsumed!
            }
        }
        #else
        buf.append("      Subfields:\n");
        for (Enumeration enumeration = subfields.keys(); enumeration.hasMoreElements();) {
            var obj: AnyObject? = subfields.get(enumeration.nextElement())
            
            if obj is List {
                for (Iterator it = ((List) obj).iterator(); it.hasNext();) {
                    let ddfs = (DDFSubfield) it.next() // DDFSubfield
                    buf.append("        ")
                    buf.append(ddfs.toString())
                    buf.append("\n");
                }
            } else {
                buf.append("        ")
                buf.append(obj.toString())
                buf.append("\n");
            }
        }
        #endif
        return buf
    }

    /// Will return an ordered list of DDFSubfield objects. If the
    /// subfield wasn't repeated, it will provide a list containing one
    /// object. Will return nil if the subfield doesn't exist.
    /// - Parameter subfieldName: The subfield to find
    /// - Returns: LinkedList of DDFSubfields or nil
    public func getSubfields(subfieldName: String) -> List<DDFSubfield>? {
        var obj: AnyObject? = subfields.get(subfieldName)
        if obj is List {
            return obj as? List
        } else if obj != nil {
            var ll =  List()
            ll.add(obj)
            return ll
        }
        return nil
    }

    /// - Parameter subfieldName: The subfield to find
    /// - Returns: A subfield or nil.
    ///
    /// If found, will return the first occurance,
    /// or the first occurance from the repeating subfield list
    public func getSubfield(subfieldName: String) -> DDFSubfield {
        var obj: AnyObject? = subfields.get(subfieldName)
        if obj is List {
            var l = obj as! List
            if l.isEmpty() == false {
                return l.get(0) as! DDFSubfield
            }
            obj = nil
        }

        // May be nil if subfield list above is empty. Not sure if
        // that's possible.
        return obj as! DDFSubfield
    }


    /// Fetch raw data pointer for a particular subfield of this field.
    ///
    /// - Parameter poSFDefn: The definition of the subfield for which the
    ///        raw data pointer is desired.
    /// - Parameter pnMaxBytes: The maximum number of bytes that can be
    ///        accessed from the returned data pointer is placed in
    ///        this int, unless it is nil.
    /// - Parameter iSubfieldIndex: The instance of this subfield to fetch.
    ///        Use zero (the default) for the first instance.
    ///
    /// - Returns: A pointer into the DDFField's data that belongs to the
    ///         subfield. This returned pointer is invalidated by the
    ///         next record read (DDFRecord::ReadRecord()) and the
    ///         returned pointer should not be freed by the
    ///         application.
    ///
    /// The passed DDFSubfieldDefn (poSFDefn) should be acquired from
    /// the DDFFieldDefn corresponding with this field. This is
    /// normally done once before reading any records. This method
    /// involves a series of calls to DDFSubfield::GetDataLength() in
    /// order to track through the DDFField data to that belonging to
    /// the requested subfield. This can be relatively expensive.
    public func getSubfieldData(poSFDefn: DDFSubfieldDefinition?, pnMaxBytes: inout Int?, iSubfieldIndex: inout Int) -> [byte]? {
       var iOffset = 0;

        if (poSFDefn == nil) {
            return nil
        }

        if (iSubfieldIndex > 0 && definition.getFixedWidth() > 0) {
            iOffset = definition.getFixedWidth() * iSubfieldIndex;
            iSubfieldIndex = 0;
        }

        var nBytesConsumed: Int? //= 0
        while (iSubfieldIndex >= 0) {
            for iSF in 0..<definition.getSubfieldCount() {
                let poThisSFDefn = definition.getSubfieldDefn(i: iSF) // DDFSubfieldDefinition

                var subPachData = [byte]() //byte[pachData.length - iOffset];
                DDFUtils.arraycopy(source: pachData!,
                                   sourceStart: iOffset,
                                   destination: &subPachData,
                                   destinationStart: 0,
                                   count: subPachData.count)

                if (poThisSFDefn == poSFDefn && iSubfieldIndex == 0) {
                    if (pnMaxBytes != nil) {
                        pnMaxBytes = pachData!.count - iOffset
                    }
                    return subPachData
                }
                poThisSFDefn?.getDataLength(pachSourceData: subPachData, nMaxBytes: subPachData.count, pnConsumedBytes: &nBytesConsumed)
                iOffset += nBytesConsumed!
            }

            iSubfieldIndex -= 1
        }

        // We didn't find our target subfield or instance!
        return nil;
    }

    public func buildSubfields() {
        var pachFieldData = pachData! // [byte]
        var nBytesRemaining: Int = pachData!.count

        for iRepeat in 0..<getRepeatCount() {

            /* -------------------------------------------------------- */
            /* Loop over all the subfields of this field, advancing */
            /* the data pointer as we consume data. */
            /* -------------------------------------------------------- */
            for iSF in 0..<definition.getSubfieldCount() {

                let ddfs = DDFSubfield(poSFDefn: definition.getSubfieldDefn(i: iSF)!, pachFieldData: pachFieldData, nBytesRemaining: nBytesRemaining)

                addSubfield(ddfSubfield: ddfs);

                // Reset data for next subfield;
               var nBytesConsumed = ddfs.getByteSize()
                nBytesRemaining -= nBytesConsumed
                var tempData = [byte] () //byte[pachFieldData.length - nBytesConsumed];
                DDFUtils.arraycopy(source: pachFieldData,
                                   sourceStart: nBytesConsumed,
                                   destination: &tempData,
                                   destinationStart: 0,
                                   count: tempData.count)
                pachFieldData = tempData;
            }
        }

    }

    func addSubfield(ddfSubfield: DDFSubfield) {
        #if DEBUG
        print("DDFField(\(definition.name)).addSubfield(\(ddfSubfield))")
        #endif

        let sfName = ddfSubfield.definition?.name.trimmingCharacters(in: .whitespaces) //.intern()
        var sf = subfields.get(sfName)
        if sf == nil {
            subfields.put(sfName, ddfSubfield)
        } else {
            if (sf is List) {
                (sf as! List).add(ddfSubfield)
            } else {
                var subList = [List]()
                subList.add(sf)
                subList.add(ddfSubfield)
                subfields.put(sfName, subList)
            }
        }
    }


    /// How many times do the subfields of this record repeat? This
    /// will always be one for non-repeating fields.
    ///
    /// - Returns: The number of times that the subfields of this record
    ///         occur in this record. This will be one for
    ///         non-repeating fields.
    public func getRepeatCount() -> Int {
        if definition.hasRepeatingSubfields == false {
            return 1;
        }

        /* -------------------------------------------------------------------- */
        /* The occurrence count depends on how many copies of this */
        /* field's list of subfields can fit into the data space. */
        /* -------------------------------------------------------------------- */
        if (definition.getFixedWidth() != 0) {
            return pachData!.count / definition.getFixedWidth()
        }

        /* -------------------------------------------------------------------- */
        /* Note that it may be legal to have repeating variable width */
        /* subfields, but I don't have any samples, so I ignore it for */
        /* now. */
        /*                                                                      */
        /*
         * The file data/cape_royal_AZ_DEM/1183XREF.DDF has a
         * repeating
         */
        /* variable length field, but the count is one, so it isn't */
        /* much value for testing. */
        /* -------------------------------------------------------------------- */
       var iOffset = 0;
       var iRepeatCount = 1;
        var nBytesConsumed: Int? //= 0

        while (true) {
            for iSF in 0..<definition.getSubfieldCount() {
                let poThisSFDefn = definition.getSubfieldDefn(i: iSF) // DDFSubfieldDefinition

                if poThisSFDefn!.getWidth() > pachData!.count - iOffset {
                    nBytesConsumed = poThisSFDefn!.getWidth()
                } else {
                    var tempData = [byte]() //byte[pachData.length - iOffset];
                    DDFUtils.arraycopy(source: pachData!,
                                       sourceStart: iOffset,
                                       destination: &tempData,
                                       destinationStart: 0,
                                       count: tempData.count)
                    poThisSFDefn?.getDataLength(pachSourceData: tempData,
                                               nMaxBytes: tempData.count,
                                               pnConsumedBytes: &nBytesConsumed)
                }
                iOffset += nBytesConsumed!
                if iOffset > pachData!.count {
                    return iRepeatCount - 1
                }
            }
            if iOffset > pachData!.count - 2 {
                return iRepeatCount
            }
            iRepeatCount += 1
        }
    }
}

