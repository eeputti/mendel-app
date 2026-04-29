#if !WIDGET_EXTENSION
//
// DateFormatter+Then.swift
// Small formatting helper kept from the original file.
//

import Foundation

extension DateFormatter {
    func then(_ block: (DateFormatter) -> Void) -> DateFormatter {
        block(self)
        return self
    }
}
#endif
