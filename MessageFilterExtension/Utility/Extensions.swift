//
//  Extensions.swift
//  MessageFilterExtension
//
//  Created by Vishal Bhadade on 25/04/25.
//

import Foundation

extension Array {
    init?<T>(unsafeData: Data, as type: T.Type = T.self) {
        guard unsafeData.count % MemoryLayout<T>.stride == 0 else { return nil }
        self = unsafeData.withUnsafeBytes {
            Array<T>(
                UnsafeBufferPointer<T>(
                    start: $0.baseAddress?.assumingMemoryBound(to: T.self),
                    count: unsafeData.count / MemoryLayout<T>.stride
                )
            )
        } as! [Element]
    }
}
