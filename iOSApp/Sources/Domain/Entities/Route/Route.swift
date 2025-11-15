//
//  EditableRoute.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/12.
//

import Foundation
import Shared

extension Route {
    func text(format: String) -> String {
        var result = ""
        var i = format.startIndex
        
        while i < format.endIndex {
            let char = format[i]
            
            let nextIndex = format.index(after: i)
            let hasNext = nextIndex < format.endIndex
            let nextChar = hasNext ? format[nextIndex] : nil

            switch char {
            case "T":
                result += title
            case "y":
                result += String(date.year)
            case "m":
                if nextChar == "2" {
                    result += String(format: "%02d", date.month)
                    i = format.index(after: nextIndex)
                    continue
                } else {
                    result += String(date.month)
                }
            case "d":
                if nextChar == "2" {
                    result += String(format: "%02d", date.day)
                    i = format.index(after: nextIndex)
                    continue
                } else {
                    result += String(date.day)
                }
            default:
                result += String(char)
            }

            i = format.index(after: i)
        }
        return result
    }
    
}
