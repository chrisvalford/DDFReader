//
//  DDFUtils.swift
//  DDFReader
//
//  Created by Christopher Alford on 27/4/21.
//

import Foundation

public class DDFUtils {
 
    /// DDFScanVariable()
    ///
    /// Establish the length of a variable length string in a  record.
    public static func scanVariable(pszRecord: [byte], nMaxChars: Int, nDelimChar: Character) -> Int {
        for n in 0..<nMaxChars - 1 {
            if pszRecord[n] == nDelimChar.asciiValue {
                return n
            }
        }
        return -1
    }

    /// DDFFetchVariable()
    ///
    /// Fetch a variable length string from a record
    public static func fetchVariable(pszRecord: [byte],
                                     nMaxChars: Int,
                                     nDelimChar1: Character,
                                     nDelimChar2: Character,
                                     pnConsumedChars: inout Int) -> String {
        var i = 0

        while i < nMaxChars - 1 && pszRecord[i] != nDelimChar1.utf8.first && pszRecord[i] != nDelimChar2.utf8.first {
            i += 1
        }

        pnConsumedChars = i
        if (i < nMaxChars
                && (pszRecord[i] == nDelimChar1.asciiValue || pszRecord[i] == nDelimChar2.asciiValue)) {
            pnConsumedChars += 1
        }

        var pszReturnBytes = [byte]() // byte[i];
        arraycopy(source: pszRecord, sourceStart: 0, destination: &pszReturnBytes, destinationStart: 0, count: i);

        return String(bytes: pszReturnBytes, encoding: .utf8)!
    }
    
    /// Copies the contents of an array into another array
    ///
    /// - Parameter source: The source array
    /// - Parameter sourceStart: The starting position to copy from source array
    /// - Parameter destination: The destination array
    /// - Parameter destinationStart: The starting position in the destination array
    /// - Parameter count: The number of elements to be copied.
    ///
    /// TODO: Increase the size of the destination array dynamically to fit
    public static func arraycopy<T>(source: [T], sourceStart: Int, destination: inout [T], destinationStart: Int, count: Int) {
        // The source data
        let sourceSubArray = source[sourceStart..<sourceStart+count]
        // The destination range
        let dRange = destinationStart..<destinationStart+count
        destination.replaceSubrange(dRange, with: sourceSubArray)
    }
    
    /// Gets a string from an array of UTF8 chars
    ///
    /// - Parameter from: The source array
    /// - Parameter start: The starting position to copy from
    /// - Parameter length: The number of elements to be copied.
    ///
    /// - Returns the String or nil
    public static func string(from source: [UInt8], start: Int, length: Int) -> String? {
        let subArray = Array(source[start...start+length-1])
        return String(decoding: subArray, as: UTF8.self)
    }
}
