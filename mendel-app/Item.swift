//
//  Item.swift
//  mendel-app
//
//  Created by Eelis Puro on 30.3.2026.
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
