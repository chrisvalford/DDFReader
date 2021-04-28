//
//  DDFFieldDefinition.swift
//  DDFReader
//
//  Created by Christopher Alford on 27/4/21.
//

import Foundation

/**
 * Information from the DDR defining one field. Note that just because
 * a field is defined for a DDFModule doesn't mean that it actually
 * occurs on any records in the module. DDFFieldDefns are normally
 * just significant as containers of the DDFSubfieldDefinitions.
 */
public class DDFFieldDefinition {

    var poModule: DDFModule?
    var pszTag: String?

    var _fieldName: String?
    var _arrayDescr: String?
    var _formatControls: String?

    var bRepeatingSubfields: Bool = false
    var nFixedWidth: Int // zero if variable.

    var _data_struct_code: DataStructCode
    var _data_type_code: DataTypeCode

    var paoSubfieldDefns = [DDFSubfieldDefinition]()

    /**
     * Fetch a pointer to the field name (tag).
     *
     * @return this is an internal copy and shouldn't be freed.
     */
    public func getName() -> String {
        return pszTag!
    }

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
        if paoSubfieldDefns.isEmpty == false {
            return paoSubfieldDefns.count
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

    /**
     * Fetch repeating flag.
     *
     * @return true if the field is marked as repeating.
     */
    public func isRepeating() -> Bool {
        return bRepeatingSubfields;
    }

    /** this is just for an S-57 hack for swedish data */
    public func setRepeating(val: Bool) {
        bRepeatingSubfields = val;
    }

    /** ********************************************************************* */
    /* DDFFieldDefn() */
    /** ********************************************************************* */

    public init() {
        poModule = nil
        pszTag = nil
        _fieldName = nil
        _arrayDescr = nil
        _formatControls = nil
    }

    public init(poModuleIn: DDFModule, pszTagIn: String, pachFieldArea: [byte]) {

        initialize(poModuleIn: poModuleIn, pszTagIn: pszTagIn, pachFieldArea: pachFieldArea);
    }

    /**
     * Initialize the field definition from the information in the DDR
     * record. This is called by DDFModule.open().
     *
     * @param poModuleIn DDFModule representing file being read.
     * @param pszTagIn the name of this field.
     * @param pachFieldArea the data bytes in the file representing
     *        the field from the header.
     */
    public func initialize(poModuleIn: DDFModule, pszTagIn: String, pachFieldArea: [byte]) -> Bool {

        /// pachFieldArea needs to be specified better. It's an
        /// offset into a character array, and we need to know what
        // it
        /// is to scope it better in Java.

       var iFDOffset = poModuleIn._fieldControlLength

        poModule = poModuleIn
        pszTag = pszTagIn

        /* -------------------------------------------------------------------- */
        /* Set the data struct and type codes. */
        /* -------------------------------------------------------------------- */
        _data_struct_code = DataStructCode.get(pachFieldArea[0])
        _data_type_code = DataTypeCode.get(pachFieldArea[1])

        #if DEBUG
            print("DDFFieldDefinition.initialize(\(pszTagIn)):\n\t\t data_struct_code = \(_data_struct_code)\n\t\t data_type_code = \(_data_type_code)\n\t\t iFDOffset = \(iFDOffset)")
        #endif

        /* -------------------------------------------------------------------- */
        /* Capture the field name, description (sub field names), and */
        /* format statements. */
        /* -------------------------------------------------------------------- */

        var tempData = [byte]() // byte[pachFieldArea.length - iFDOffset];
        DDFUtils.arraycopy(source: pachFieldArea,
                           sourceStart: iFDOffset,
                           destination: &tempData,
                           destinationStart: 0,
                           count: pachFieldArea.count - iFDOffset);

        var nCharsConsumed = 0

        _fieldName = DDFUtils.fetchVariable(pszRecord: tempData,
                                            nMaxChars: tempData.count,
                                            nDelimChar1: DDF_UNIT_TERMINATOR,
                                            nDelimChar2: DDF_FIELD_TERMINATOR,
                                            pnConsumedChars: &nCharsConsumed);
        #if DEBUG
        print("DDFFieldDefinition.initialize(\(pszTagIn)): created field name \(_fieldName ?? "Unknown")")
        #endif

        iFDOffset += nCharsConsumed

        tempData  = [byte]() // byte[pachFieldArea.length - iFDOffset];
        DDFUtils.arraycopy(source: pachFieldArea,
                           sourceStart: iFDOffset,
                           destination: &tempData,
                           destinationStart: 0,
                           count: pachFieldArea.count - iFDOffset);
        _arrayDescr = DDFUtils.fetchVariable(pszRecord: tempData,
                                             nMaxChars: tempData.count,
                                             nDelimChar1: DDF_UNIT_TERMINATOR,
                                             nDelimChar2: DDF_FIELD_TERMINATOR,
                                             pnConsumedChars: &nCharsConsumed);
        iFDOffset += nCharsConsumed

        tempData = [byte]() // byte[pachFieldArea.length - iFDOffset];
        DDFUtils.arraycopy(source: pachFieldArea,
                           sourceStart: iFDOffset,
                           destination: &tempData,
                           destinationStart: 0,
                           count: pachFieldArea.count - iFDOffset);

        _formatControls = DDFUtils.fetchVariable(pszRecord: tempData,
                                                 nMaxChars: tempData.count,
                                                 nDelimChar1: DDF_UNIT_TERMINATOR,
                                                 nDelimChar2: DDF_FIELD_TERMINATOR,
                                                 pnConsumedChars: &nCharsConsumed)

        /* -------------------------------------------------------------------- */
        /* Parse the subfield info. */
        /* -------------------------------------------------------------------- */
        if _data_struct_code != DataStructCode.ELEMENTARY {
            if !buildSubfieldDefns(pszSublist: _arrayDescr) {
                return false
            }

            if !applyFormats(_formatControls: _formatControls) {
                return false
            }
        }

        return true;
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
        buf.append(pszTag!)
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
        buf.append(_data_struct_code.toString())
        buf.append("\n")
        buf.append("      _data_type_code = ")
        buf.append(_data_type_code.toString())
        buf.append("\n")

        if paoSubfieldDefns.isEmpty == false {
            for definition in paoSubfieldDefns {
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
            bRepeatingSubfields = true
            sublist = sublist.substring(from: 1)
        }

        let sublistNoQuotes = sublist.replacingOccurrences(of: "\"", with: "\0")
        let papszSubfieldNames = sublistNoQuotes.components(separatedBy: "!")

        paoSubfieldDefns = [DDFSubfieldDefinition]()
        
        for subfieldName in papszSubfieldNames {
            let ddfsd = DDFSubfieldDefinition()
            ddfsd.setName(pszNewName: subfieldName)
            paoSubfieldDefns.append(ddfsd)
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
        var i: Int
        var pszReturn: String

        for (i = 0; i < pszSrc.count && (nBracket > 0 || pszSrc.char(at: i) != ","); i++) {
            if (pszSrc.char(at: i) == "(") {
                nBracket += 1
            } else if (pszSrc.char(at: i) == ")") {
                nBracket -= 1
            }
        }

        if (pszSrc.char(at: 0) == "(") {
            pszReturn = pszSrc.substring(1, i - 2);
        } else {
            pszReturn = pszSrc.substring(0, i);
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
                
                let nRepeatString = pszSrc.substring(orig_iSrc, iSrc);
                nRepeat = Int(nRepeatString)

                let pszContents = pszSrc.substring(from: iSrc).extractSubstring()
                let pszExpandedContents = expandFormat(pszSrc: pszContents);

                for i in 0..<nRepeat {
                    szDest.append(pszExpandedContents);
                    if (i < nRepeat - 1) {
                        szDest.append(",");
                    }
                }

                if iSrc == "(" {
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
            print("DDFFieldDefinition: Format controls for \(pszTag ?? "Unknown Tag") field missing brackets {\(_formatControls)} : length = \(_formatControls.count), starts with {\(_formatControls.char(at: 0))}, ends with {\(_formatControls.char(at: _formatControls.count - 1))}")
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

       var iFormatItem = 0
        for (Iterator it = papszFormatItems.iterator(); it.hasNext(); iFormatItem++) {

            let pszPastPrefix: String = it.next();

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
            
            if iFormatItem > paoSubfieldDefns.count {
                print("DDFFieldDefinition: Got more formats than subfields for fied \(pszTag ?? "Unknown Tag")")
                break
            }
            
            if !paoSubfieldDefns[iFormatItem].setFormat(pszFormat: pszPastPrefix) {
                print("DDFFieldDefinition had problem setting format for \(pszPastPrefix)")
                return false
            }
        }
        
        /* -------------------------------------------------------------------- */
        /* Verify that we got enough formats, cleanup and return. */
        /* -------------------------------------------------------------------- */
        if iFormatItem < paoSubfieldDefns.count {
            print("DDFFieldDefinition: Got fewer formats than subfields for field \(pszTag ?? "Unknown Tag") got (\(iFormatItem), should have \(paoSubfieldDefns.count))")
            return false
        }

        /* -------------------------------------------------------------------- */
        /* If all the fields are fixed width, then we are fixed width */
        /* too. This is important for repeating fields. */
        /* -------------------------------------------------------------------- */
        nFixedWidth = 0;
        for ddfsd in paoSubfieldDefns {
            if ddfsd.getWidth() == 0 {
                nFixedWidth = 0
                break
            } else {
                nFixedWidth += ddfsd.getWidth()
            }
        }
        return true
    }

    /**
     * Find a subfield definition by it's mnemonic tag.
     *
     * @param pszMnemonic The name of the field.
     *
     * @return The subfield pointer, or nil if there isn't any such
     *         subfield.
     */
    public func findSubfieldDefn(pszMnemonic: String) -> DDFSubfieldDefinition? {
        if (paoSubfieldDefns != nil) {
            for (Iterator it = paoSubfieldDefns.iterator(); pszMnemonic != nil
                    && it.hasNext();) {
                let ddfsd = it.next() // DDFSubfieldDefinition
                if (pszMnemonic.equalsIgnoreCase(ddfsd.getName())) {
                    return ddfsd;
                }
            }
        }

        return nil;
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
        if paoSubfieldDefns == nil || i < 0 || i >= paoSubfieldDefns.count {
            return nil;
        }
        return paoSubfieldDefns[i] // (DDFSubfieldDefinition)
    }

    public class DataStructCode {
        public static let ELEMENTARY = DataStructCode(code: Character("0"), name: "elementary")
        public static let VECTOR = DataStructCode(code: Character("1"), name: "vector")
        public static let ARRAY = DataStructCode(code: Character("2"), name: "array")
        public static let CONCATENATED = DataStructCode(code: Character("3"), name: "concatenated")

        var code = Character("0")
        var prettyName: String

        public init(code: Character, name: String) {
            self.code = code
            self.prettyName = name
        }

        public func getCode() -> Character {
            return code
        }

        public func toString() -> String {
            return prettyName;
        }

        public static func get(c: Character) -> DataStructCode {
            if c == CONCATENATED.getCode() {
                return CONCATENATED
            }
            if (c == VECTOR.getCode()) {
                return VECTOR
            }
            if (c == ARRAY.getCode()) {
                return ARRAY
            }
            if (c == ELEMENTARY.getCode()) {
                return ELEMENTARY
            }

            #if DEBUG
            print("DDFFieldDefinition tested for unknown code: \(c)")
            #endif
            return ELEMENTARY
        }
    }

    public class DataTypeCode {
        public static let CHAR_STRING = DataTypeCode(code: Character("0"), name: "character string")
        public static let IMPLICIT_POINT = DataTypeCode(code: Character("1"), name: "implicit point")
        public static let EXPLICIT_POINT = DataTypeCode(code: Character("2"), name: "explicit point")
        public static let EXPLICIT_POINT_SCALED = DataTypeCode(code: Character("3"), name: "explicit point scaled")
        public static let CHAR_BIT_STRING = DataTypeCode(code: Character("4"), name: "character bit string")
        public static let BIT_STRING = DataTypeCode(code: Character("5"), name: "bit string")
        public static let MIXED_DATA_TYPE = DataTypeCode(code: Character("6"), name: "mixed data type")

        var code = Character("0")
        var prettyName: String

        public init(code: Character, name: String) {
            self.code = code
            self.prettyName = name
        }

        public func getCode() -> Character {
            return code
        }

        public func toString() -> String {
            return prettyName;
        }

        public static func get(c: Character) -> DataTypeCode {
            if (c == IMPLICIT_POINT.getCode()) {
                return IMPLICIT_POINT
            }
            if (c == EXPLICIT_POINT.getCode()) {
                return EXPLICIT_POINT
            }
            if (c == EXPLICIT_POINT_SCALED.getCode()) {
                return EXPLICIT_POINT_SCALED
            }
            if (c == CHAR_BIT_STRING.getCode()) {
                return CHAR_BIT_STRING
            }
            if (c == BIT_STRING.getCode()) {
                return BIT_STRING
            }
            if (c == MIXED_DATA_TYPE.getCode()) {
                return MIXED_DATA_TYPE
            }
            if (c == CHAR_STRING.getCode()) {
                return CHAR_STRING
            }

            #if DEBUG
            print("DDFFieldDefinition tested for unknown data type code: \(c)")
            #endif
            return CHAR_STRING
        }
    }
}
