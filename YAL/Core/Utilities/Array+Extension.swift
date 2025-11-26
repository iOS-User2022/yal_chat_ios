//
//  Array+Extension.swift
//  YAL
//
//  Created by Vishal Bhadade on 18/11/25.
//

import Foundation

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var res: [[Element]] = []
        res.reserveCapacity((count + size - 1) / size)
        var i = 0
        while i < count {
            let j = Swift.min(i + size, count)
            res.append(Array(self[i..<j]))
            i = j
        }
        return res
    }
}

extension Collection {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [Array(self)] }
        var result: [[Element]] = []
        result.reserveCapacity((self.count + size - 1) / size)
        var i = startIndex
        while i != endIndex {
            let j = index(i, offsetBy: size, limitedBy: endIndex) ?? endIndex
            result.append(Array(self[i..<j]))
            i = j
        }
        return result
    }
}
