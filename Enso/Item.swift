//
//  Item.swift
//  Enso
//
//  Created by Sami Hindi on 19.12.2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
