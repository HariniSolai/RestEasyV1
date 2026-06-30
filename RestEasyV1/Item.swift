//
//  Item.swift
//  RestEasyV1
//
//  Created by 35 BGCC Loan Library on 6/30/26.
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
