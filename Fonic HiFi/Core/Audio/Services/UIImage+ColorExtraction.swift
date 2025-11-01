//
//  UIImage+ColorExtraction.swift
//  Fonic HiFi
//
//  Created on 2025-10-02.
//  iOS 26+ Dynamic Color Extraction using Core Image
//

import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

extension UIImage {
    /// Extracts average color using CIAreaAverage filter
    /// [Verified-Apple] CIFilter.areaAverage() available iOS 14.0+
    var averageColor: Color? {
        guard let inputImage = CIImage(image: self) else { return nil }

        let filter = CIFilter.areaAverage()
        filter.inputImage = inputImage
        filter.extent = inputImage.extent

        guard let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil,
        )

        return Color(
            red: Double(bitmap[0]) / 255,
            green: Double(bitmap[1]) / 255,
            blue: Double(bitmap[2]) / 255,
        )
    }

    /// Downscales image for faster extraction
    private func downscaled(to size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Fast average color with 50x50 downscaling
    var fastAverageColor: Color? {
        let targetSize = CGSize(width: 50, height: 50)
        guard let resized = downscaled(to: targetSize) else {
            return averageColor
        }
        return resized.averageColor
    }
}
