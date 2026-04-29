#if !WIDGET_EXTENSION
//
// SignatureAssetStore.swift
// Persists the symbolic signature as a simple PNG asset.
//

import SwiftUI
import UIKit

final class SignatureAssetStore {
    static let shared = SignatureAssetStore()

    private init() {}

    func saveSignature(points: [CGPoint], size: CGSize = CGSize(width: 600, height: 280)) -> URL? {
        guard !points.isEmpty else { return nil }

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let path = UIBezierPath()
            path.lineWidth = 4
            path.lineCapStyle = .round
            path.lineJoinStyle = .round

            if let first = points.first {
                path.move(to: first)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }

            UIColor(red: 14 / 255, green: 14 / 255, blue: 12 / 255, alpha: 1).setStroke()
            path.stroke()
        }

        guard let data = image.pngData() else { return nil }
        let url = signaturesDirectory.appendingPathComponent("commitment-signature.png")
        do {
            try FileManager.default.createDirectory(
                at: signaturesDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private var signaturesDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("KestoOnboarding", isDirectory: true)
    }
}
#endif
