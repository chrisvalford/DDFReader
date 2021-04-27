//
//  DDFUtils.swift
//  DDFReader
//
//  Created by Christopher Alford on 27/4/21.
//

import Foundation

public class DDFUtils {
    /** ********************************************************************* */
    /* DDFScanVariable() */
    /*                                                                      */
    /* Establish the length of a variable length string in a */
    /* record. */
    /** ********************************************************************* */

    public static func scanVariable(pszRecord: [byte], nMaxChars: Int, nDelimChar: Character) -> Int {
        var i = -1
        repeat {
            i += 1
        } while i < nMaxChars - 1 && pszRecord[i] != nDelimChar
        return i;
    }

    /** ********************************************************************* */
    /* DDFFetchVariable() */
    /*                                                                      */
    /* Fetch a variable length string from a record, and allocate */
    /* it as a new string (with CPLStrdup()). */
    /** ********************************************************************* */

    public static func fetchVariable(pszRecord: [byte],
                                     nMaxChars: Int,
                                     nDelimChar1: Character,
                                     nDelimChar2: Character,
                                     pnConsumedChars: inout Int) -> String {
        var i = -1
        repeat {
            i += 1
        } while i < nMaxChars - 1 && pszRecord[i] != nDelimChar1 && pszRecord[i] != nDelimChar2

        pnConsumedChars = i;
        if (i < nMaxChars && (pszRecord[i] == nDelimChar1 || pszRecord[i] == nDelimChar2)) {
            pnConsumedChars += 1
        }

        var pszReturnBytes = [byte]() // byte[i];
        System.arraycopy(pszRecord, 0, pszReturnBytes, 0, i);

        return String(bytes: pszReturnBytes, encoding: .utf8)!
    }
}
