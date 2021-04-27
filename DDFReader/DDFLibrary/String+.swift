//
//  String+.swift
//  DDFReader
//
//  Created by Christopher Alford on 27/4/21.
//

import Foundation

extension String {
    func index(from: Int) -> Index {
        return self.index(startIndex, offsetBy: from)
    }

    func substring(from: Int) -> String {
        let fromIndex = index(from: from)
        return String(self[fromIndex...])
    }

    func substring(to: Int) -> String {
        let toIndex = index(from: to)
        return String(self[..<toIndex])
    }

    func substring(with r: Range<Int>) -> String {
        let startIndex = index(from: r.lowerBound)
        let endIndex = index(from: r.upperBound)
        return String(self[startIndex..<endIndex])
    }
    // char(at: at:) returns a character at an integer (zero-based) position.
    // example:
    // let str = "hello"
    // var second = str.char(at: at: 1)
    //  -> "e"
    func char(at: Int) -> Character {
        let charIndex = self.index(self.startIndex, offsetBy: at)
        return self[charIndex]
    }
    
    func equalsIgnoreCase(_ b: String) -> Bool {
        return self.caseInsensitiveCompare(b) == .orderedSame
    }
}
/*
let str = "Hello, playground"
print(str.substring(from: 7))         // playground
print(str.substring(to: 5))           // Hello
print(str.substring(with: 7..<11))    // play
print(str.char(at: 7))
*/
