#if !WIDGET_EXTENSION
//
// CoachResponse.swift
// Structured coach recommendation response model.
//

import Foundation

struct CoachResponse: Codable {
    let status: String
    let headline: String
    let reason: String
    let recommended_session: String
    let caution: String
}
#endif
