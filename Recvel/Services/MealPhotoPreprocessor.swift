import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Reduce una foto del carrete antes de analizarla o enviarla.
///
/// La foto original de un iPhone son ~12-48 MP: decodificarla entera cuesta
/// decenas de MB, y ademas suele venir en HEIC aunque el cliente de Gemini la
/// declaraba `image/jpeg`. `CGImageSourceCreateThumbnailAtIndex` decodifica
/// directamente al tamaño pedido (nunca materializa la imagen completa) y
/// aplica la orientacion EXIF.
enum MealPhotoPreprocessor {
    static func downscaled(_ data: Data, maxPixel: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// JPEG real (no HEIC renombrado) de la imagen ya reducida.
    static func jpegData(from image: CGImage, quality: Double = 0.8) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(
            destination, image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }
}
