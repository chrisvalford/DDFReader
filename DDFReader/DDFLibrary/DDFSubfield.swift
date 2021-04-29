//
//  DDFSubfield.swift
//  DDFReader
//
//  Created by Christopher Alford on 27/4/21.
//

import Foundation

/**
 * Class containing subfield information for a DDFField object.
 */
public class DDFSubfield {

    /**
     * A DDFSubfieldDefinition defining the admin part of the file
     * that contains the subfield data.
     */
    var definition: DDFSubfieldDefinition?
    /**
     * The object containing the value of the field.
     */
    var value: AnyObject?
    /**
     * The number of bytes the field took up in the data file.
     */
    var byteSize: Int

    init() {}

    /**
     * Create a subfield with a definition and a value.
     */
    public init(ddfsd: DDFSubfieldDefinition, value: AnyObject) {
        self.definition = ddfsd
        self.value = value
    }

    /**
     * Create a subfield with a definition and the bytes containing
     * the information for the value. The definition parameters will
     * tell the DDFSubfield what kind of object to create for the
     * data.
     */
    public init(poSFDefn: DDFSubfieldDefinition, pachFieldData: [byte], nBytesRemaining: Int) {
        definition = poSFDefn;
        var nBytesConsumed: Int?
        let ddfdt: DDFDataType = poSFDefn.dataType

        if (ddfdt == DDFDataType.DDFInt) {
            value = definition!.extractIntData(pachSourceData: pachFieldData,
                                             nMaxBytes: nBytesRemaining,
                                             pnConsumedBytes: &nBytesConsumed)
        } else if (ddfdt == DDFDataType.DDFFloat) {
            value = definition!.extractFloatData(pachSourceData: pachFieldData,
                                           nMaxBytes: nBytesRemaining,
                                           pnConsumedBytes: &nBytesConsumed)
        } else if (ddfdt == DDFDataType.DDFString || ddfdt == DDFDataType.DDFBinaryString) {
            value = definition!.extractStringData(pachSourceData: pachFieldData,
                                            nMaxBytes: nBytesRemaining,
                                            pnConsumedBytes: &nBytesConsumed)
        }

        byteSize = nBytesConsumed!
    }

    public func getByteSize() -> Int {
        return byteSize
    }

    /**
     * Get the value of the subfield as an int. Returns 0 if the value
     * is 0 or isn't a number.
     */
    public func intValue() -> Int {
        let obj = value
        if obj is Int {
            return obj as! Int
        }
        return 0
    }

    /**
     * Get the value of the subfield as a float. Returns 0f if the
     * value is 0 or isn't a number.
     */
    public func floatValue() -> Double {
        let obj = value
        if obj is Double {
            return obj as! Double
        }
        return 0
    }

    public func stringValue() -> String {
        let obj = value
        if obj != nil {
            return obj as! String
        }
        return ""
    }

    /**
     * Return a string 'key = value', describing the field and its
     * value.
     */
    public func toString() -> String{
        if definition != nil {
            return "\(definition!.name) = \(String(describing: value))"
        }
        return ""
    }
}
