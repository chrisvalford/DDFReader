//
//  DDFSubfieldDefinition.swift
//  DDFReader
//
//  Created by Christopher Alford on 27/4/21.
//

import Foundation

/**
 * Information from the DDR record describing one subfield of a DDFFieldDefn.
 * All subfields of a field will occur in each occurrence of that field (as a
 * DDFField) in a DDFRecord. Subfield's actually contain formatted data (as
 * instances within a record).
 *
 * @author Guillaume Pelletier provided fix for Big Endian support (important
 *         for S-57)
 */
public class DDFSubfieldDefinition {
    
    var name: String {
        didSet { name = name.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    var pszFormatString: String
    private (set) var dataType: DDFDataType
    var eBinaryFormat: DDFBinaryFormat
    
    /**
     * bIsVariable determines whether we using the chFormatDelimeter (true), or
     * the fixed width (false).
     */
    var bIsVariable: Bool
    
    var chFormatDelimeter: Character
    var nFormatWidth: Int
    
    enum DDFBinaryFormat: Int {
        case NotBinary = 0
        case UInt = 1
        case SInt = 2
        case FPReal = 3
        case FloatReal = 4
        case FloatComplex = 5
    }
    
    public func getWidth() -> Int {
        return nFormatWidth;
    }
    
    /** Get pointer to subfield format string */
    public func getFormat() -> String {
        return pszFormatString;
    }
    
    public init() {
        bIsVariable = true;
        nFormatWidth = 0;
        chFormatDelimeter = DDF_UNIT_TERMINATOR;
        eBinaryFormat = DDFBinaryFormat.NotBinary;
        dataType = DDFDataType.DDFString;
        pszFormatString = ""
    }
    
    /**
     * While interpreting the format string we don't support:
     * <UL>
     * <LI>Passing an explicit terminator for variable length field.
     * <LI>'X' for unused data ... this should really be filtered
     * <LI>out by DDFFieldDefinition.applyFormats(), but isn't.
     * <LI>'B' bitstrings that aren't a multiple of eight.
     * </UL>
     */
    public func setFormat(pszFormat: String) -> Bool {
        pszFormatString = pszFormat;
        
        #if DEBUG
        print("DDFSubfieldDefinition.setFormat(" + pszFormat + ")");
        #endif
        
        /* -------------------------------------------------------------------- */
        /* These values will likely be used. */
        /* -------------------------------------------------------------------- */
        if pszFormatString.count > 1 && pszFormatString.char(at: 1) == "(" {
            
            // Need to loop through characters to grab digits, and
            // then get integer version. If we look a the atoi code,
            // it checks for non-digit characters and then stops.
            var i = 3;
            while i < pszFormat.count && pszFormat.char(at: i).isNumber {
                i += 1
            }
            
            nFormatWidth = Int(pszFormat.substring(2, i))!
            bIsVariable = (nFormatWidth == 0)
        } else {
            bIsVariable = true
        }
        
        /* -------------------------------------------------------------------- */
        /* Interpret the format string. */
        /* -------------------------------------------------------------------- */
        switch (pszFormatString.char(at: 0)) {
        
        case "A", "C": // It isn't clear to me how this is different than 'A'
            dataType = .DDFString
            
        case "R":
            dataType = .DDFFloat;
            
        case "I", "S":
            dataType = .DDFInt;
            
        case "B", "b":
            // Is the width expressed in bits? (is it a bitstring)
            bIsVariable = false;
            if (pszFormatString.char(at: 1) == "(") {
                
                var numEndIndex = 2
                while numEndIndex < pszFormatString.count && pszFormatString.char(at: numEndIndex).isNumber {
                    numEndIndex += 1
                }
                
                let numberString = pszFormatString.substring(2, numEndIndex)
                nFormatWidth = Int(numberString)!
                
                if nFormatWidth % 8 != 0 {
                    print("DDFSubfieldDefinition.setFormat() problem with \(pszFormatString.char(at: 0)) not being modded with 8 evenly");
                    return false
                }
                
                nFormatWidth = Int(numberString)! / 8
                eBinaryFormat = .SInt // good default, works for SDTS.
                
                if (nFormatWidth < 5) {
                    dataType = .DDFInt;
                } else {
                    dataType = .DDFBinaryString;
                }
                
            } else { // or do we have a binary type indicator? (is it binary)
                
                eBinaryFormat = DDFBinaryFormat(rawValue: Int(pszFormatString.char(at: 1).asciiValue! - "0".utf8.first!))!
                
                var numEndIndex = 2;
                while numEndIndex < pszFormatString.count && pszFormatString.char(at: numEndIndex).isNumber {
                    numEndIndex += 1
                }
                nFormatWidth = Int(pszFormatString.substring(2,numEndIndex))!
                
                if (eBinaryFormat == DDFBinaryFormat.SInt || eBinaryFormat == DDFBinaryFormat.UInt) {
                    dataType = DDFDataType.DDFInt;
                } else {
                    dataType = DDFDataType.DDFFloat;
                }
            }
            
        case "X":
            // 'X' is extra space, and shouldn't be directly assigned
            // to a
            // subfield ... I haven't encountered it in use yet
            // though.
            print("DDFSubfieldDefinition: Format type of \(pszFormatString.char(at: 0)) not supported.")
            
            return false
        default:
            print("DDFSubfieldDefinition: Format type of \(pszFormatString.char(at: 0)) not recognised.")
            return false
        }
        
        return true
    }
    
    /**
     * Write out subfield definition info. A variety of information about this
     * field definition is written to the give debugging file handle.
     */
    public func toString() -> String {
        var sb = "    DDFSubfieldDefn:\n"
        sb.append("        Label = ")
        sb.append(name)
        sb.append("\n")
        sb.append("        FormatString = ")
        sb.append(pszFormatString)
        sb.append("\n")
        return sb
    }
    
    /**
     * Scan for the end of variable length data. Given a pointer to the data for
     * this subfield (from within a DDFRecord) this method will return the
     * number of bytes which are data for this subfield. The number of bytes
     * consumed as part of this field can also be fetched. This number may be
     * one longer than the length if there is a terminator character used.
     * <p>
     *
     * This method is mainly for internal use, or for applications which want
     * the raw binary data to interpret themselves. Otherwise use one of
     * ExtractStringData(), ExtractIntData() or ExtractFloatData().
     *
     * @param pachSourceData
     *            The pointer to the raw data for this field. This may have come
     *            from DDFRecord::GetData(), taking into account skip factors
     *            over previous subfields data.
     * @param nMaxBytes
     *            The maximum number of bytes that are accessible after
     *            pachSourceData.
     * @param pnConsumedBytes
     *            the number of bytes used.
     *
     * @return The number of bytes at pachSourceData which are actual data for
     *         this record (not including unit, or field terminator).
     */
    public func getDataLength(pachSourceData: [byte], nMaxBytes: Int, pnConsumedBytes: inout Int?) -> Int {
        if bIsVariable == false {
            if nFormatWidth > nMaxBytes {
                print("DDFSubfieldDefinition: Only \(nMaxBytes) bytes available for subfield  \(name) with format string \(pszFormatString) ... returning shortened data.")
                if pnConsumedBytes != nil {
                    pnConsumedBytes = nMaxBytes
                }
                return nMaxBytes
            } else {
                if pnConsumedBytes != nil {
                    pnConsumedBytes = nFormatWidth
                }
                return nFormatWidth
            }
        } else {
            var nLength = 0
            var bCheckFieldTerminator = true
            
            /*
             * We only check for the field terminator because of some buggy
             * datasets with missing format terminators. However, we have found
             * the field terminator is a legal character within the fields of
             * some extended datasets (such as JP34NC94.000). So we don't check
             * for the field terminator if the field appears to be multi-byte
             * which we established by the first character being out of the
             * ASCII printable range (32-127).
             */
            
            if pachSourceData[0] < 32 || pachSourceData[0] >= 127 {
                bCheckFieldTerminator = false
            }
            
            while nLength < nMaxBytes && pachSourceData[nLength] != chFormatDelimeter.utf8.first {
                if bCheckFieldTerminator && pachSourceData[nLength] == DDF_FIELD_TERMINATOR.utf8.first {
                    break
                }
                nLength += 1
            }
            if pnConsumedBytes != nil {
                if nMaxBytes == 0 {
                    pnConsumedBytes = nLength;
                } else {
                    pnConsumedBytes = nLength + 1
                }
            }
            return nLength
        }
    }
    
    /**
     * Extract a zero terminated string containing the data for this subfield.
     * Given a pointer to the data for this subfield (from within a DDFRecord)
     * this method will return the data for this subfield. The number of bytes
     * consumed as part of this field can also be fetched. This number may be
     * one longer than the string length if there is a terminator character
     * used.
     * <p>
     *
     * This function will return the raw binary data of a subfield for types
     * other than DDFString, including data past zero chars. This is the
     * standard way of extracting DDFBinaryString subfields for instance.
     * <p>
     *
     * @param pachSourceData
     *            The pointer to the raw data for this field. This may have come
     *            from DDFRecord::GetData(), taking into account skip factors
     *            over previous subfields data.
     * @param nMaxBytes
     *            The maximum number of bytes that are accessible after
     *            pachSourceData.
     * @param pnConsumedBytes
     *            Pointer to an integer into which the number of bytes consumed
     *            by this field should be written. May be nil to ignore. This
     *            is used as a skip factor to increment pachSourceData to point
     *            to the next subfields data.
     *
     * @return A pointer to a buffer containing the data for this field. The
     *         returned pointer is to an internal buffer which is invalidated on
     *         the next ExtractStringData() call on this DDFSubfieldDefn(). It
     *         should not be freed by the application.
     */
    func extractStringData(pachSourceData: [byte], nMaxBytes: Int, pnConsumedBytes: inout Int?) -> String {
        var oldConsumed = 0
        if (pnConsumedBytes != nil) {
            oldConsumed = pnConsumedBytes!
        }
        
        let nLength = getDataLength(pachSourceData: pachSourceData, nMaxBytes: nMaxBytes, pnConsumedBytes: &pnConsumedBytes);
        let ns = DDFUtils.string(from: pachSourceData, start: 0, length: nLength)!
        
        //if (Debug.debugging("iso8211detail") && pnConsumedBytes != nil) {
        #if DEBUG
        print("        extracting string data from \(nLength) bytes of \(pachSourceData.count): \(ns): consumed \(pnConsumedBytes ?? 0) vs. \(oldConsumed), max = \(nMaxBytes)")
        #endif
        return ns
    }
    
    /**
     * Extract a subfield value as a float. Given a pointer to the data for this
     * subfield (from within a DDFRecord) this method will return the floating
     * point data for this subfield. The number of bytes consumed as part of
     * this field can also be fetched. This method may be called for any type of
     * subfield, and will return zero if the subfield is not numeric.
     *
     * @param pachSourceData
     *            The pointer to the raw data for this field. This may have come
     *            from DDFRecord::GetData(), taking into account skip factors
     *            over previous subfields data.
     * @param nMaxBytes
     *            The maximum number of bytes that are accessible after
     *            pachSourceData.
     * @param pnConsumedBytes
     *            Pointer to an integer into which the number of bytes consumed
     *            by this field should be written. May be nil to ignore. This
     *            is used as a skip factor to increment pachSourceData to point
     *            to the next subfields data.
     *
     * @return The subfield's numeric value (or zero if it isn't numeric).
     */
    public func extractFloatData(pachSourceData: [byte], nMaxBytes: Int, pnConsumedBytes: inout Int?) -> Double {
        
        switch (pszFormatString.char(at: 0)) {
        case "A","I","R","S","C":
            let dataString = extractStringData(pachSourceData: pachSourceData, nMaxBytes: nMaxBytes, pnConsumedBytes: &pnConsumedBytes)
            if dataString.count == 0 {
                return 0
            }
            do {
                return Double(dataString)!
            } catch {
                #if DEBUG
                print("DDFSubfieldDefinition.extractFloatData: number format problem: " + dataString);
                #endif
                return 0
            }
            
        case "B","b":
            var abyData = [byte]() // byte[8];
            
            if pnConsumedBytes != nil {
                pnConsumedBytes = nFormatWidth
            }
            
            if nFormatWidth > nMaxBytes {
                print("DDFSubfieldDefinition: format width is greater than max bytes for float")
                return 0.0
            }
            
            // Byte swap the data if it isn't in machine native
            // format. In any event we copy it into our buffer to
            // ensure it is word aligned.
            //
            // DFD - don't think this applies to Java, since it's
            // always big endian
            
            // if (pszFormatString.char(at: 0) == 'B') ||
            // (pszFormatString.char(at: 0) == 'b') {
            // for (int i = 0; i < nFormatWidth; i++) {
            // abyData[nFormatWidth-i-1] = pachSourceData[i];
            // }
            // } else {
            // DDFUtils.arraycopy(pachSourceData, 0, abyData, 8-nFormatWidth,
            // nFormatWidth);
            DDFUtils.arraycopy(source: pachSourceData,
                               sourceStart: 0,
                               destination: &abyData,
                               destinationStart: 0,
                               count: nFormatWidth)
            // }
            
            // Interpret the bytes of data.
            switch (eBinaryFormat) {
            case DDFBinaryFormat.UInt, DDFBinaryFormat.SInt, DDFBinaryFormat.FloatReal:
                return pszFormatString.char(at: 0) == "B" ? MoreMath.BuildIntegerBE(abyData) : MoreMath.BuildIntegerLE(abyData);
                
            // if (nFormatWidth == 1)
            // return(abyData[0]);
            // else if (nFormatWidth == 2)
            // return(*((GUInt16 *) abyData));
            // else if (nFormatWidth == 4)
            // return(*((GUInt32 *) abyData));
            // else {
            // return 0.0;
            // }
            
            // case DDFBinaryFormat.SInt:
            // if (nFormatWidth == 1)
            // return(*((signed char *) abyData));
            // else if (nFormatWidth == 2)
            // return(*((GInt16 *) abyData));
            // else if (nFormatWidth == 4)
            // return(*((GInt32 *) abyData));
            // else {
            // return 0.0;
            // }
            
            // case DDFBinaryFormat.FloatReal:
            // if (nFormatWidth == 4)
            // return(*((float *) abyData));
            // else if (nFormatWidth == 8)
            // return(*((double *) abyData));
            // else {
            // return 0.0;
            // }
            
            case DDFBinaryFormat.NotBinary, DDFBinaryFormat.FPReal, DDFBinaryFormat.FloatComplex:
                return 0.0
            }
            break;
        // end of 'b'/'B' case.
        
        default:
            break
            
        }
        
        return 0.0
    }
    
    /**
     * Extract a subfield value as an integer. Given a pointer to the data for
     * this subfield (from within a DDFRecord) this method will return the int
     * data for this subfield. The number of bytes consumed as part of this
     * field can also be fetched. This method may be called for any type of
     * subfield, and will return zero if the subfield is not numeric.
     *
     * @param pachSourceData
     *            The pointer to the raw data for this field. This may have come
     *            from DDFRecord::GetData(), taking into account skip factors
     *            over previous subfields data.
     * @param nMaxBytes
     *            The maximum number of bytes that are accessible after
     *            pachSourceData.
     * @param pnConsumedBytes
     *            Pointer to an integer into which the number of bytes consumed
     *            by this field should be written. May be nil to ignore. This
     *            is used as a skip factor to increment pachSourceData to point
     *            to the next subfields data.
     *
     * @return The subfield's numeric value (or zero if it isn't numeric).
     */
    public func extractIntData(pachSourceData: [byte], nMaxBytes: Int, pnConsumedBytes: inout Int?) -> Int {
        
        switch (pszFormatString.char(at: 0)) {
        case "A","I","R","S","C":
            let dataString = extractStringData(pachSourceData: pachSourceData, nMaxBytes: nMaxBytes, pnConsumedBytes: &pnConsumedBytes)
            if dataString.count == 0 {
                return 0
            }
            
            do {
                return Int(dataString)!
            } catch  {
                #if DEBUG
                print("DDFSubfieldDefinition.extractIntData: number format problem: \(dataString)")
                #endif
                return 0
            }
            
        case "B","b":
            var abyData = [byte]() // byte[4];
            if nFormatWidth > nMaxBytes {
                print("DDFSubfieldDefinition: format width is greater than max bytes for int");
                return 0
            }
            
            if (pnConsumedBytes != nil) {
                pnConsumedBytes = nFormatWidth;
            }
            
            // DDFUtils.arraycopy(pachSourceData, 0, abyData, 4-nFormatWidth,
            // nFormatWidth);
            DDFUtils.arraycopy(source: pachSourceData,
                               sourceStart: 0,
                               destination: &abyData,
                               destinationStart: 0,
                               count: nFormatWidth)
            
            // Interpret the bytes of data.
            switch (eBinaryFormat) {
            case DDFBinaryFormat.UInt, DDFBinaryFormat.SInt, DDFBinaryFormat.FloatReal:
                return pszFormatString.char(at: 0) == "B" ? MoreMath.BuildIntegerBE(abyData) : MoreMath.BuildIntegerLE(abyData)
                
            // case DDFBinaryFormat.UInt:
            // if (nFormatWidth == 4)
            // return((int) *((GUInt32 *) abyData));
            // else if (nFormatWidth == 1)
            // return(abyData[0]);
            // else if (nFormatWidth == 2)
            // return(*((GUInt16 *) abyData));
            // else {
            // CPLAssert(false);
            // return 0;
            // }
            
            // case DDFBinaryFormat.SInt:
            // if (nFormatWidth == 4)
            // return(*((GInt32 *) abyData));
            // else if (nFormatWidth == 1)
            // return(*((signed char *) abyData));
            // else if (nFormatWidth == 2)
            // return(*((GInt16 *) abyData));
            // else {
            // CPLAssert(false);
            // return 0;
            // }
            
            // case DDFBinaryFormat.FloatReal:
            // if (nFormatWidth == 4)
            // return((int) *((float *) abyData));
            // else if (nFormatWidth == 8)
            // return((int) *((double *) abyData));
            // else {
            // CPLAssert(false);
            // return 0;
            // }
            
            case DDFBinaryFormat.NotBinary, DDFBinaryFormat.FPReal, DDFBinaryFormat.FloatComplex:
                return 0
            }
            break
        // end of 'b'/'B' case.
        
        default:
            return 0
        }
        
        return 0
    }
    
    /**
     * Dump subfield value to debugging file.
     *
     * @param pachData
     *            Pointer to data for this subfield.
     * @param nMaxBytes
     *            Maximum number of bytes available in pachData.
     */
    public func dumpData(pachData: [byte], nMaxBytes: Int) -> String {
        var sb = ""
        if (dataType == DDFDataType.DDFFloat) {
            sb.append("      Subfield ")
            sb.append(name)
            sb.append("=")
            sb.append(extractFloatData(pachSourceData: pachData, nMaxBytes: nMaxBytes, pnConsumedBytes: 0))
            sb.append("\n");
        } else if (dataType == DDFDataType.DDFInt) {
            sb.append("      Subfield ")
            sb.append(name)
            sb.append("=")
            sb.append(extractIntData(pachSourceData: pachData, nMaxBytes: nMaxBytes, pnConsumedBytes: 0))
            sb.append("\n");
        } else if (dataType == DDFDataType.DDFBinaryString) {
            sb.append("      Subfield ")
            sb.append(name)
            sb.append("=")
            sb.append(extractStringData(pachSourceData: pachData, nMaxBytes: nMaxBytes, pnConsumedBytes: 0))
            sb.append("\n");
        } else {
            sb.append("      Subfield ")
            sb.append(name)
            sb.append("=")
            sb.append(extractStringData(pachSourceData: pachData, nMaxBytes: nMaxBytes, pnConsumedBytes: 0))
            sb.append("\n");
        }
        return sb
    }
    
}
