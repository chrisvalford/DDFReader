//
//  DDFFieldDefinition.swift
//  DDFReader
//
//  Created by Christopher Alford on 27/4/21.
//

import Foundation

/**
 * Information from the DDR defining one field. Note that just because
 * a field is defined for a CatalogModel doesn't mean that it actually
 * occurs on any records in the module. DDFFieldDefns are normally
 * just significant as containers of the DDFSubfieldDefinitions.
 */
public class DDFFieldDefinition {

    var poModule: CatalogModel?
    private (set) var name: String

    var _fieldName: String?
    var _arrayDescr: String?
    var _formatControls: String?

    var hasRepeatingSubfields: Bool = false
    var nFixedWidth: Int // zero if variable.

    var _data_struct_code: DataStructCode
    var _data_type_code: DataTypeCode

    private (set) var subfieldDefinitions = [DDFSubfieldDefinition]()

    /**
     * Fetch a longer descriptio of this field.
     *
     * @return this is an internal copy and shouldn't be freed.
     */
    public func getDescription() -> String {
        return _fieldName!
    }

    /**
     * Get the number of subfields.
     */
    public func getSubfieldCount() -> Int {
        if subfieldDefinitions.isEmpty == false {
            return subfieldDefinitions.count
        }
        return 0
    }

    /**
     * Get the width of this field. This function isn't normally used
     * by applications.
     *
     * @return The width of the field in bytes, or zero if the field
     *         is not apparently of a fixed width.
     */
    public func getFixedWidth() -> Int {
        return nFixedWidth;
    }

    /** ********************************************************************* */
    /* DDFFieldDefn() */
    /** ********************************************************************* */

    init() {
        poModule = nil
        _fieldName = nil
        _arrayDescr = nil
        _formatControls = nil
    }

    public init(poModuleIn: CatalogModel, pszTagIn: String, pachFieldArea: [byte]) {
        initialize(poModuleIn: poModuleIn, pszTagIn: pszTagIn, pachFieldArea: pachFieldArea)
    }

    /**
     * Initialize the field definition from the information in the DDR
     * record. This is called by CatalogModel.open().
     *
     * @param poModuleIn CatalogModel representing file being read.
     * @param pszTagIn the name of this field.
     * @param pachFieldArea the data bytes in the file representing
     *        the field from the header.
     */
    public func initialize(poModuleIn: CatalogModel, pszTagIn: String, pachFieldArea: [byte]) {

        /// pachFieldArea needs to be specified better. It's an
        /// offset into a character array, and we need to know what
        // it
        /// is to scope it better in Java.

       var iFDOffset = poModuleIn._fieldControlLength

        poModule = poModuleIn
        name = pszTagIn

        /* -------------------------------------------------------------------- */
        /* Set the data struct and type codes. */
        /* -------------------------------------------------------------------- */
        _data_struct_code = DataStructCode(Int(String(Character(UnicodeScalar(pachFieldArea[0]))))!)
        _data_type_code = DataTypeCode(Int(String(Character(UnicodeScalar(pachFieldArea[1]))))!)

        #if DEBUG
            print("DDFFieldDefinition.initialize(\(pszTagIn)):\n\t\t data_struct_code = \(_data_struct_code)\n\t\t data_type_code = \(_data_type_code)\n\t\t iFDOffset = \(iFDOffset)")
        #endif

        /* -------------------------------------------------------------------- */
        /* Capture the field name, description (sub field names), and */
        /* format statements. */
        /* -------------------------------------------------------------------- */

        var tempData = [byte]() // byte[pachFieldArea.length - iFDOffset];
        DDFUtils.arraycopy(source: pachFieldArea,
                           sourceStart: iFDOffset!,
                           destination: &tempData,
                           destinationStart: 0,
                           count: pachFieldArea.count - iFDOffset!);

        var nCharsConsumed = 0

        _fieldName = DDFUtils.fetchVariable(pszRecord: tempData,
                                            nMaxChars: tempData.count,
                                            nDelimChar1: DDF_UNIT_TERMINATOR,
                                            nDelimChar2: DDF_FIELD_TERMINATOR,
                                            pnConsumedChars: &nCharsConsumed);
        #if DEBUG
        print("DDFFieldDefinition.initialize(\(pszTagIn)): created field name \(_fieldName ?? "Unknown")")
        #endif

        iFDOffset! += nCharsConsumed

        tempData  = [byte]() // byte[pachFieldArea.length - iFDOffset];
        DDFUtils.arraycopy(source: pachFieldArea,
                           sourceStart: iFDOffset!,
                           destination: &tempData,
                           destinationStart: 0,
                           count: pachFieldArea.count - iFDOffset!);
        _arrayDescr = DDFUtils.fetchVariable(pszRecord: tempData,
                                             nMaxChars: tempData.count,
                                             nDelimChar1: DDF_UNIT_TERMINATOR,
                                             nDelimChar2: DDF_FIELD_TERMINATOR,
                                             pnConsumedChars: &nCharsConsumed);
        iFDOffset! += nCharsConsumed

        tempData = [byte]() // byte[pachFieldArea.length - iFDOffset];
        DDFUtils.arraycopy(source: pachFieldArea,
                           sourceStart: iFDOffset!,
                           destination: &tempData,
                           destinationStart: 0,
                           count: pachFieldArea.count - iFDOffset!);

        _formatControls = DDFUtils.fetchVariable(pszRecord: tempData,
                                                 nMaxChars: tempData.count,
                                                 nDelimChar1: DDF_UNIT_TERMINATOR,
                                                 nDelimChar2: DDF_FIELD_TERMINATOR,
                                                 pnConsumedChars: &nCharsConsumed)

        /* -------------------------------------------------------------------- */
        /* Parse the subfield info. */
        /* -------------------------------------------------------------------- */
        if _data_struct_code != DataStructCode.elementary {
            if !buildSubfieldDefns(pszSublist: _arrayDescr!) {
                print("buildSubfieldDefns FAILED!")
                //return false
            }

            if !applyFormats(_formatControls: _formatControls!) {
                print("applyFormats FAILED")
                //return false
            }
        }

        //return true
    }

    /**
     * Write out field definition info.
     *
     * A variety of information about this field definition, and all
     * its subfields are written out too.
     */
    public func toString() -> String {
        var buf = "  DDFFieldDefn:\n"
        buf.append("      Tag = ")
        buf.append(name)
        buf.append("\n")
        buf.append("      _fieldName = ")
        buf.append(_fieldName!)
        buf.append("\n")
        buf.append("      _arrayDescr = ")
        buf.append(_arrayDescr!)
        buf.append("\n")
        buf.append("      _formatControls = ")
        buf.append(_formatControls!)
        buf.append("\n")
        buf.append("      _data_struct_code = ")
        buf.append("\(_data_struct_code)")
        buf.append("\n")
        buf.append("      _data_type_code = ")
        buf.append(_data_type_code.toString())
        buf.append("\n")

        if subfieldDefinitions.isEmpty == false {
            for definition in subfieldDefinitions {
                buf.append(definition.toString())
            }
        }

        return buf
    }

    /**
     * Based on the list contained in the string, build a set of
     * subfield definitions.
     */
    func buildSubfieldDefns(pszSublist: String) -> Bool {
        var sublist = pszSublist
        
        if sublist.hasPrefix("*") {
            hasRepeatingSubfields = true
            sublist = sublist.substring(from: 1)
        }

        let sublistNoQuotes = sublist.replacingOccurrences(of: "\"", with: "\0")
        let papszSubfieldNames = sublistNoQuotes.components(separatedBy: "!")

        subfieldDefinitions = [DDFSubfieldDefinition]()
        
        for subfieldName in papszSubfieldNames {
            let ddfsd = DDFSubfieldDefinition()
            ddfsd.name = subfieldName
            subfieldDefinitions.append(ddfsd)
        }
        return true
    }

    /**
     * Extract a substring terminated by a comma (or end of string).
     * Commas in brackets are ignored as terminated with bracket
     * nesting understood gracefully. If the returned string would
     * being and end with a bracket then strip off the brackets.
     * <P>
     * Given a string like "(A,3(B,C),D),X,Y)" return "A,3(B,C),D".
     * Give a string like "3A,2C" return "3A".
     */
    func extractSubstring(pszSrc: String) -> String {
        var nBracket = 0;
        var pszReturn: String
        var i = 0
        while i < pszSrc.count && (nBracket > 0 || pszSrc.char(at: i) != ",") {
            if (pszSrc.char(at: i) == "(") {
                nBracket += 1
            } else if (pszSrc.char(at: i) == ")") {
                nBracket -= 1
            }
        i += 1
        }

        if (pszSrc.char(at: 0) == "(") {
            pszReturn = pszSrc[1...(i - 2)]
        } else {
            pszReturn = pszSrc[0...i]
        }

        return pszReturn;
    }

    /**
     * Given a string that contains a coded size symbol, expand it
     * out.
     */
    func expandFormat(pszSrc: String) -> String {
        var szDest = ""
       var iSrc = 0;
       var nRepeat = 0;

        while (iSrc < pszSrc.count) {
            /*
             * This is presumably an extra level of brackets around
             * some binary stuff related to rescanning which we don't
             * care to do (see 6.4.3.3 of the standard. We just strip
             * off the extra layer of brackets
             */
            if ((iSrc == 0 || pszSrc.char(at: iSrc - 1) == ",") && pszSrc.char(at: iSrc) == "(") {
                let pszContents = pszSrc.substring(from: iSrc).extractSubstring()
                let pszExpandedContents = expandFormat(pszSrc: pszContents);

                szDest.append(pszExpandedContents)
                iSrc = iSrc + pszContents.count + 2;

            } else if (iSrc == 0 || pszSrc.char(at: iSrc - 1) == ",") && pszSrc.char(at: iSrc).isNumber { // isDigit
                // this is a repeated subclause
               let orig_iSrc = iSrc;

                // skip over repeat count.
                while pszSrc.char(at: iSrc).isNumber {
                    iSrc += 1
                }
                
                let nRepeatString = pszSrc[orig_iSrc...iSrc]
                nRepeat = Int(nRepeatString)!

                let pszContents = pszSrc.substring(from: iSrc).extractSubstring()
                let pszExpandedContents = expandFormat(pszSrc: pszContents);

                for i in 0..<nRepeat {
                    szDest.append(pszExpandedContents);
                    if (i < nRepeat - 1) {
                        szDest.append(",");
                    }
                }

                if iSrc == 40 { // Open parentheis "("
                    iSrc += pszContents.count + 2;
                } else {
                    iSrc += pszContents.count
                }

            } else {
                iSrc += 1
                szDest.append(pszSrc.char(at: iSrc));
            }
        }

        return szDest
    }

    /**
     * This method parses the format string partially, and then
     * applies a subfield format string to each subfield object. It in
     * turn does final parsing of the subfield formats.
     */
    func applyFormats(_formatControls: String) -> Bool {
        var pszFormatList: String
        var papszFormatItems = [String]()

        /* -------------------------------------------------------------------- */
        /* Verify that the format string is contained within brackets. */
        /* -------------------------------------------------------------------- */
        if _formatControls.count < 2 || !_formatControls.hasPrefix("(") || !_formatControls.hasSuffix(")") {
            print("DDFFieldDefinition: Format controls for \(name ) field missing brackets {\(_formatControls)} : length = \(_formatControls.count), starts with {\(_formatControls.char(at: 0))}, ends with {\(_formatControls.char(at: _formatControls.count - 1))}")
            return false
        }

        /* -------------------------------------------------------------------- */
        /* Duplicate the string, and strip off the brackets. */
        /* -------------------------------------------------------------------- */

        pszFormatList = expandFormat(pszSrc: _formatControls);

        #if DEBUG
        print("DDFFieldDefinition.applyFormats{" + _formatControls + "} expanded to {" + pszFormatList + "} ");
        #endif

        /* -------------------------------------------------------------------- */
        /* Tokenize based on commas. */
        /* -------------------------------------------------------------------- */
        let pszFormatListNoQuotes = pszFormatList.replacingOccurrences(of: "\"", with: "\0")
        papszFormatItems = pszFormatListNoQuotes.components(separatedBy: ",")
        //papszFormatItems = PropUtils.parseMarkers(pszFormatList, ",");

        /* -------------------------------------------------------------------- */
        /* Apply the format items to subfields. */
        /* -------------------------------------------------------------------- */

//       var iFormatItem = 0
//        for (Iterator it = papszFormatItems.iterator(); it.hasNext(); iFormatItem++) {
//
//            let pszPastPrefix: String = it.next();
//        }

        var iFormatItem = 0
        for item in papszFormatItems {
            
            var pszPastPrefix = item
            var pppIndex = 0
            // Skip over digits...
            while pszPastPrefix.char(at: pppIndex).isNumber {
                pppIndex += 1
            }
            pszPastPrefix = pszPastPrefix.substring(from: pppIndex)
            
            // Did we get too many formats for the subfields created by names?
            // This may be legal by the 8211 specification, but isn't encountered in
            // any formats we care about so we just blow.
            
            if iFormatItem > subfieldDefinitions.count {
                print("DDFFieldDefinition: Got more formats than subfields for fied \(name)")
                break
            }
            
            if !subfieldDefinitions[iFormatItem].setFormat(pszFormat: pszPastPrefix) {
                print("DDFFieldDefinition had problem setting format for \(pszPastPrefix)")
                return false
            }
        }
        
        /* -------------------------------------------------------------------- */
        /* Verify that we got enough formats, cleanup and return. */
        /* -------------------------------------------------------------------- */
        if iFormatItem < subfieldDefinitions.count {
            print("DDFFieldDefinition: Got fewer formats than subfields for field \(name) got (\(iFormatItem), should have \(subfieldDefinitions.count))")
            return false
        }

        /* -------------------------------------------------------------------- */
        /* If all the fields are fixed width, then we are fixed width */
        /* too. This is important for repeating fields. */
        /* -------------------------------------------------------------------- */
        nFixedWidth = 0;
        for ddfsd in subfieldDefinitions {
            if ddfsd.getWidth() == 0 {
                nFixedWidth = 0
                break
            } else {
                nFixedWidth += ddfsd.getWidth()
            }
        }
        return true
    }

    
    /// Find a subfield definition by it's tag.
    ///
    /// - Parameter named: The name of the field.
    ///
    /// - Returns: The subfield, or nil if not found.
    ///
    public func findSubfieldDefinition(named: String) -> DDFSubfieldDefinition? {
        for subfieldDefinition in subfieldDefinitions {
            if named.equalsIgnoreCase(subfieldDefinition.name) {
                return subfieldDefinition
            }
        }
        return nil
    }

    /**
     * Fetch a subfield by index.
     *
     * @param i The index subfield index. (Between 0 and
     *        GetSubfieldCount()-1)
     * @return The subfield pointer, or nil if the index is out of
     *         range.
     */
    public func getSubfieldDefn(i: Int) -> DDFSubfieldDefinition? {
        if i < 0 || i >= subfieldDefinitions.count {
            return nil;
        }
        return subfieldDefinitions[i] // (DDFSubfieldDefinition)
    }

    public enum DataStructCode: CaseIterable {
        case elementary
        case vector
        case array
        case concatenated
        
        init(_ value: Int) {
            switch value {
            case 0:
                self = .elementary
            case 1:
                self = .vector
            case 2:
                self = .array
            case 3:
                self = .concatenated
            default:
                self = .elementary
            }
        }
    }

    public enum DataTypeCode: CaseIterable {
        case CHAR_STRING
        case IMPLICIT_POINT
        case EXPLICIT_POINT
        case EXPLICIT_POINT_SCALED
        case CHAR_BIT_STRING
        case BIT_STRING
        case MIXED_DATA_TYPE
        
        init(_ value: Int) {
            switch value {
            case 0:
                self = .CHAR_STRING
            case 1:
                self = .IMPLICIT_POINT
            case 2:
                self = .EXPLICIT_POINT
            case 3:
                self = .EXPLICIT_POINT_SCALED
            case 4:
                self = .CHAR_BIT_STRING
            case 5:
                self = .BIT_STRING
            case 6:
                self = .MIXED_DATA_TYPE
            default:
                self = .CHAR_STRING
            }
        }

        public func toString() -> String {
            switch self {
            case .CHAR_STRING: return "character string"
            case .IMPLICIT_POINT: return "implicit point"
            case .EXPLICIT_POINT: return "explicit point"
            case .EXPLICIT_POINT_SCALED: return "explicit point scaled"
            case .CHAR_BIT_STRING: return "character bit string"
            case .BIT_STRING: return "bit string"
            case .MIXED_DATA_TYPE: return "mixed data type"
            }
        }
    }
}
