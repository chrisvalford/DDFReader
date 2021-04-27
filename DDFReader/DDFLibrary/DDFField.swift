//
//  DDFField.swift
//  DDFReader
//
//  Created by Christopher Alford on 27/4/21.
//

import Foundation

/**
 * This object represents one field in a DDFRecord. This models an
 * instance of the fields data, rather than it's data definition which
 * is handled by the DDFFieldDefn class. Note that a DDFField doesn't
 * have DDFSubfield children as you would expect. To extract subfield
 * values use GetSubfieldData() to find the right data pointer and
 * then use ExtractIntData(), ExtractFloatData() or
 * ExtractStringData().
 */
public class DDFField {

    var poDefn: DDFFieldDefinition
    var pachData: [UInt8]
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

    public init(poDefnIn: DDFFieldDefinition, pachDataIn: [byte]) {
        this(poDefnIn, pachDataIn, true);
    }

    public init(poDefnIn: DDFFieldDefinition, pachDataIn: [byte], doSubfields: Bool) {
        initialize(poDefnIn, pachDataIn);
        if (doSubfields) {
            buildSubfields();
        }
    }

    public func initialize(poDefnIn: DDFFieldDefinition, pachDataIn: [byte]) {
        pachData = pachDataIn;
        poDefn = poDefnIn;
        subfields = Hashtable();
    }

    /**
     * Set how many bytes to add to the data position for absolute
     * position in the data file for the field data.
     */
    func setHeaderOffset(headerOffsetIn: Int) {
        headerOffset = headerOffsetIn;
    }

    /**
     * Get how many bytes to add to the data position for absolute
     * position in the data file for the field data.
     */
    public func getHeaderOffset() -> Int {
        return headerOffset;
    }

    /**
     * Return the pointer to the entire data block for this record.
     * This is an internal copy, and shouldn't be freed by the
     * application. If nil, then check the dataPosition and
     * daataLength for byte offsets for the data in the file, and go
     * get it yourself. This is done for really large files where it
     * doesn't make sense to load the data.
     */
    public func getData() -> [byte] {
        return pachData;
    }

    /**
     * Return the number of bytes in the data block returned by
     * GetData().
     */
    public func getDataSize() -> Int {
        if (pachData != nil) {
            return pachData.count
        } else {
            return 0
        }
    }

    /** Fetch the corresponding DDFFieldDefn. */
    public func getFieldDefn() -> DDFFieldDefinition {
        return poDefn;
    }

    /**
     * If getData() returns nil, it'll be your responsibilty to go
     * after the data you need for this field.
     *
     * @return the byte offset into the source file to start reading
     *         this field.
     */
    public func getDataPosition() -> Int {
        return dataPosition;
    }

    /**
     * If getData() returns nil, it'll be your responsibilty to go
     * after the data you need for this field.
     *
     * @return the number of bytes contained in the source file for
     *         this field.
     */
    public func getDataLength() -> Int {
        return dataLength;
    }

    /**
     * Creates a string with variety of information about this field,
     * and all it's subfields is written to the given debugging file
     * handle. Note that field definition information (ala
     * DDFFieldDefn) isn't written.
     *
     * @return String containing info.
     */
    public func toString() -> String {
        var buf = "  DDFField:\n"
        buf.append("\tTag = ")
        buf.append(poDefn.getName())
        buf.append("\n");
        buf.append("\tDescription = ")
        buf.append(poDefn.getDescription())
        buf.append("\n");
        let size = getDataSize();
        buf.append("\tDataSize = ")
        buf.append(size)
        buf.append("\n");

        if (pachData == nil) {
            buf.append("\tHeader offset = ")
            buf.append(headerOffset)
            buf.append("\n");
            buf.append("\tData position = ")
            buf.append(dataPosition)
            buf.append("\n");
            buf.append("\tData length = ")
            buf.append(dataLength)
            buf.append("\n");
            return buf
        }

        buf.append("\tData = ");
        for (int i = 0; i < Math.min(size, 40); i++) {
            if (pachData[i] < 32 || pachData[i] > 126) {
                buf.append(" | ")
                buf.append(pachData[i])
            } else {
                buf.append(pachData[i])
            }
        }

        if (size > 40) {
            buf.append("...")
        }
        buf.append("\n")

        /* -------------------------------------------------------------------- */
        /* dump the data of the subfields. */
        /* -------------------------------------------------------------------- */
        if (Debug.debugging("iso8211.raw")) {
           IntiOffset = 0;
            MutableInt nBytesConsumed = new MutableInt(0);

            for (int nLoopCount = 0; nLoopCount < getRepeatCount(); nLoopCount++) {
                if (nLoopCount > 8) {
                    buf.append("      ...\n");
                    break;
                }

                for (int i = 0; i < poDefn.getSubfieldCount(); i++) {
                    [byte] subPachData = new byte[pachData.length - iOffset];
                    System.arraycopy(pachData,
                            iOffset,
                            subPachData,
                            0,
                            subPachData.length);

                    buf.append(poDefn.getSubfieldDefn(i).dumpData(subPachData,
                            subPachData.length));

                    poDefn.getSubfieldDefn(i).getDataLength(subPachData,
                            subPachData.length,
                            nBytesConsumed);
                    iOffset += nBytesConsumed.value;
                }
            }
        } else {
            buf.append("      Subfields:\n");

            for (Enumeration enumeration = subfields.keys(); enumeration.hasMoreElements();) {
                Object obj = subfields.get(enumeration.nextElement());

                if (obj instanceof List) {
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
        }
        return buf
    }

    /**
     * Will return an ordered list of DDFSubfield objects. If the
     * subfield wasn't repeated, it will provide a list containing one
     * object. Will return nil if the subfield doesn't exist.
     */
    public func getSubfields(subfieldName: String) -> List<DDFSubfield>? {
        Object obj = subfields.get(subfieldName);
        if (obj instanceof List) {
            return (List) obj;
        } else if (obj != nil) {
            LinkedList ll = new LinkedList();
            ll.add(obj);
            return ll;
        }

        return nil;
    }

    /**
     * Will return a DDFSubfield object with the given name, or the
     * first one off the list for a repeating subfield. Will return
     * nil if the subfield doesn't exist.
     */
    public func getSubfield(subfieldName: String) -> DDFSubfield {
        Object obj = subfields.get(subfieldName);
        if (obj instanceof List) {
            List l = (List) obj;
            if (!l.isEmpty()) {
                return (DDFSubfield) (l.get(0));
            }
            obj = nil;
        }

        // May be nil if subfield list above is empty. Not sure if
        // that's possible.
        return (DDFSubfield) obj;
    }

    /**
     * Fetch raw data pointer for a particular subfield of this field.
     *
     * The passed DDFSubfieldDefn (poSFDefn) should be acquired from
     * the DDFFieldDefn corresponding with this field. This is
     * normally done once before reading any records. This method
     * involves a series of calls to DDFSubfield::GetDataLength() in
     * order to track through the DDFField data to that belonging to
     * the requested subfield. This can be relatively expensive.
     * <p>
     *
     * @param poSFDefn The definition of the subfield for which the
     *        raw data pointer is desired.
     * @param pnMaxBytes The maximum number of bytes that can be
     *        accessed from the returned data pointer is placed in
     *        this int, unless it is nil.
     * @param iSubfieldIndex The instance of this subfield to fetch.
     *        Use zero (the default) for the first instance.
     *
     * @return A pointer into the DDFField's data that belongs to the
     *         subfield. This returned pointer is invalidated by the
     *         next record read (DDFRecord::ReadRecord()) and the
     *         returned pointer should not be freed by the
     *         application.
     */
    public func getSubfieldData(poSFDefn: DDFSubfieldDefinition?, pnMaxBytes: inout Int, iSubfieldIndex: inout Int) -> [byte]? {
       var iOffset = 0;

        if (poSFDefn == nil) {
            return nil
        }

        if (iSubfieldIndex > 0 && poDefn.getFixedWidth() > 0) {
            iOffset = poDefn.getFixedWidth() * iSubfieldIndex;
            iSubfieldIndex = 0;
        }

        var nBytesConsumed = 0
        while (iSubfieldIndex >= 0) {
            for iSF in 0..<poDefn.getSubfieldCount() {
                let poThisSFDefn = poDefn.getSubfieldDefn(iSF) // DDFSubfieldDefinition

                var subPachData = [byte]() //byte[pachData.length - iOffset];
                System.arraycopy(pachData,
                        iOffset,
                        subPachData,
                        0,
                        subPachData.length);

                if (poThisSFDefn == poSFDefn && iSubfieldIndex == 0) {
                    if (pnMaxBytes != nil) {
                        pnMaxBytes.value = pachData.length - iOffset;
                    }
                    return subPachData;
                }
                poThisSFDefn.getDataLength(subPachData,
                        subPachData.length,
                        nBytesConsumed);
                iOffset += nBytesConsumed.value;
            }

            iSubfieldIndex -= 1
        }

        // We didn't find our target subfield or instance!
        return nil;
    }

    public func buildSubfields() {
        let pachFieldData = pachData // [byte]
       var nBytesRemaining = pachData.count

        for iRepeat in 0..<getRepeatCount() {

            /* -------------------------------------------------------- */
            /* Loop over all the subfields of this field, advancing */
            /* the data pointer as we consume data. */
            /* -------------------------------------------------------- */
            for iSF in 0..<poDefn.getSubfieldCount() {

                let ddfs = DDFSubfield(poDefn.getSubfieldDefn(iSF), pachFieldData, nBytesRemaining)

                addSubfield(ddfs);

                // Reset data for next subfield;
               var nBytesConsumed = ddfs.getByteSize()
                nBytesRemaining -= nBytesConsumed
                var tempData = [byte] () //byte[pachFieldData.length - nBytesConsumed];
                System.arraycopy(pachFieldData,
                        nBytesConsumed,
                        tempData,
                        0,
                        tempData.length);
                pachFieldData = tempData;
            }
        }

    }

    func addSubfield(ddfs: DDFSubfield) {
        if (Debug.debugging("iso8211")) {
            Debug.output("DDFField(" + getFieldDefn().getName()
                    + ").addSubfield(" + ddfs + ")");
        }

        String sfName = ddfs.getDefn().getName().trim().intern();
        Object sf = subfields.get(sfName);
        if (sf == nil) {
            subfields.put(sfName, ddfs);
        } else {
            if (sf instanceof List) {
                ((List) sf).add(ddfs);
            } else {
                Vector subList = new Vector();
                subList.add(sf);
                subList.add(ddfs);
                subfields.put(sfName, subList);
            }
        }
    }

    /**
     * How many times do the subfields of this record repeat? This
     * will always be one for non-repeating fields.
     *
     * @return The number of times that the subfields of this record
     *         occur in this record. This will be one for
     *         non-repeating fields.
     */
    public func getRepeatCount() -> Int {
        if (!poDefn.isRepeating()) {
            return 1;
        }

        /* -------------------------------------------------------------------- */
        /* The occurrence count depends on how many copies of this */
        /* field's list of subfields can fit into the data space. */
        /* -------------------------------------------------------------------- */
        if (poDefn.getFixedWidth() != 0) {
            return pachData.length / poDefn.getFixedWidth();
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
       var nBytesConsumed = 0

        while (true) {
            for iSF in 0..<poDefn.getSubfieldCount() {
                let poThisSFDefn = poDefn.getSubfieldDefn(iSF) // DDFSubfieldDefinition

                if poThisSFDefn.getWidth() > pachData.length - iOffset {
                    nBytesConsumed.value = poThisSFDefn.getWidth();
                } else {
                    var tempData = [byte]() //byte[pachData.length - iOffset];
                    System.arraycopy(pachData,
                            iOffset,
                            tempData,
                            0,
                            tempData.length);
                    poThisSFDefn.getDataLength(tempData,
                            tempData.length,
                            nBytesConsumed);
                }

                iOffset += nBytesConsumed.value;
                if iOffset > pachData.length {
                    return iRepeatCount - 1;
                }
            }

            if iOffset > pachData.count - 2 {
                return iRepeatCount
            }

            iRepeatCount += 1
        }
    }
}

