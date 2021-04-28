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
    

    // Extract a substring terminated by a comma (or end of string).
    // Commas in brackets are ignored as terminated with bracket
    // nesting understood gracefully. If the returned string would
    // being and end with a bracket then strip off the brackets.
    // Given a string like "(A,3(B,C),D),X,Y)" return "A,3(B,C),D".
    // Give a string like "3A,2C" return "3A".
    func extractSubstring() -> String
    {
        var returnArray = [Character]()

        // Keep a count of the opening and closing brackets
        var bracketCount = 0
        let characters = Array(self)

        for c in characters {
            if c == "\0" { break }

            else if c == "," {
                if bracketCount == 0 {
                    break
                }
                returnArray.append(c)
            }

            else if c == "(" {
                bracketCount += 1
                if bracketCount > 1 {
                    returnArray.append(c)
                }
            }
            else if c == ")" {
                if bracketCount > 1 {
                    returnArray.append(c)
                }
                bracketCount -= 1
            }

            else {
                returnArray.append(c)
            }
        }

        return String(returnArray)
    }
    
    subscript(_ i: Int) -> String {
        let idx1 = index(startIndex, offsetBy: i)
        let idx2 = index(idx1, offsetBy: 1)
        return String(self[idx1..<idx2])
    }
    
    subscript (r: Range<Int>) -> String {
        let start = index(startIndex, offsetBy: r.lowerBound)
        let end = index(startIndex, offsetBy: r.upperBound)
        return String(self[start ..< end])
    }
    
    subscript (r: CountableClosedRange<Int>) -> String {
        let startIndex =  self.index(self.startIndex, offsetBy: r.lowerBound)
        let endIndex = self.index(startIndex, offsetBy: r.upperBound - r.lowerBound)
        return String(self[startIndex...endIndex])
    }
}
/*
let str = "Hello, playground"
print(str.substring(from: 7))         // playground
print(str.substring(to: 5))           // Hello
print(str.substring(with: 7..<11))    // play
print(str.char(at: 7))
 
 let ss1 = "(A,3(B,C),D),X,Y)".extractSubstring()
 let tt1 = "3A,2C".extractSubstring()
*/

