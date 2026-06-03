import Foundation
import Vision
import UIKit

struct TextBlock: Identifiable, Equatable {
    let id: UUID
    let text: String
    var translatedText: String?
    let boundingBox: CGRect // Normalized: origin bottom-left (Vision default)
    
    init(text: String, translatedText: String? = nil, boundingBox: CGRect) {
        self.id = UUID()
        self.text = text
        self.translatedText = translatedText
        self.boundingBox = boundingBox
    }
    
    /// Converts Vision normalized bounding box (bottom-left origin) to SwiftUI layout coordinates (top-left origin)
    func swiftUIBoundingBox(in size: CGSize) -> CGRect {
        return CGRect(
            x: boundingBox.origin.x * size.width,
            y: (1.0 - boundingBox.origin.y - boundingBox.size.height) * size.height,
            width: boundingBox.size.width * size.width,
            height: boundingBox.size.height * size.height
        )
    }
}

class OCRService {
    
    func performOCR(on image: UIImage, completion: @escaping (Result<[TextBlock], Error>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(NSError(domain: "OCRService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to load CGImage from UIImage"])))
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.success([]))
                return
            }
            
            let textBlocks = observations.compactMap { observation -> TextBlock? in
                guard let topCandidate = observation.topCandidates(1).first else { return nil }
                
                // Only keep blocks that actually contain text
                let trimmed = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                
                return TextBlock(
                    text: topCandidate.string,
                    boundingBox: observation.boundingBox
                )
            }
            
            completion(.success(textBlocks))
        }
        
        // High accuracy is required for Chinese OCR
        request.recognitionLevel = .accurate
        
        // Prioritize Chinese (Simplified and Traditional), fall back to English
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
        request.usesLanguageCorrection = true
        
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(.failure(error))
            }
        }
    }
}

// Helper extension to map UIImage.Orientation to CGImagePropertyOrientation for Vision
extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
