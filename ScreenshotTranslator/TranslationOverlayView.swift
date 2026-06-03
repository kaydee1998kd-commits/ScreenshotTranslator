import SwiftUI

struct TranslationOverlayView: View {
    let image: UIImage
    let blocks: [TextBlock]
    let maskOpacity: Double
    let showOverlays: Bool
    
    var body: some View {
        GeometryReader { geometry in
            if showOverlays {
                let imageSize = image.size
                let containerSize = geometry.size
                
                // Calculate the actual frame of the scaled image
                let rect = calculateImageRect(containerSize: containerSize, imageSize: imageSize)
                
                ZStack(alignment: .topLeading) {
                    // Loop through blocks and place them at their calculated positions
                    ForEach(blocks) { block in
                        if let translated = block.translatedText, !translated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            
                            // Map normalized bounding box to image rect
                            let width = block.boundingBox.size.width * rect.width
                            let height = block.boundingBox.size.height * rect.height
                            
                            // Adjust Y axis (Vision bottom-left -> SwiftUI top-left)
                            let x = rect.origin.x + (block.boundingBox.origin.x * rect.width)
                            let y = rect.origin.y + ((1.0 - block.boundingBox.origin.y - block.boundingBox.size.height) * rect.height)
                            
                            TranslationBlockView(
                                originalText: block.text,
                                translatedText: translated,
                                width: width,
                                height: height,
                                maskOpacity: maskOpacity
                            )
                            .position(x: x + width / 2.0, y: y + height / 2.0)
                        }
                    }
                }
            }
        }
    }
    
    // Calculates the bounds of the image inside the Aspect Ratio Fit container
    private func calculateImageRect(containerSize: CGSize, imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0 && imageSize.height > 0 else { return .zero }
        
        let containerRatio = containerSize.width / containerSize.height
        let imageRatio = imageSize.width / imageSize.height
        
        var width: CGFloat = 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        
        if imageRatio > containerRatio {
            // Letterboxed top and bottom
            width = containerSize.width
            height = containerSize.width / imageRatio
            x = 0
            y = (containerSize.height - height) / 2.0
        } else {
            // Letterboxed left and right
            height = containerSize.height
            width = containerSize.height * imageRatio
            x = (containerSize.width - width) / 2.0
            y = 0
        }
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

struct TranslationBlockView: View {
    let originalText: String
    let translatedText: String
    let width: CGFloat
    let height: CGFloat
    let maskOpacity: Double
    
    @State private var showTooltip = false
    
    var body: some View {
        ZStack {
            // Translucent backdrop to hide/obscure the original Chinese characters
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(uiColor: .systemBackground))
                .opacity(maskOpacity)
                .frame(width: width, height: height)
                .shadow(color: Color.black.opacity(maskOpacity > 0.3 ? 0.15 : 0), radius: 1, x: 0, y: 1)
            
            // The translated English text
            Text(translatedText)
                .font(.system(size: calculateFontSize(width: width, height: height)))
                .foregroundColor(.primary)
                .lineLimit(nil)
                .minimumScaleFactor(0.4)
                .multilineTextAlignment(.center)
                .padding(2)
                .frame(width: width, height: height, alignment: .center)
        }
        .onTapGesture {
            showTooltip.toggle()
        }
        .popover(isPresented: $showTooltip) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Original Chinese")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .bold()
                    Text(originalText)
                        .font(.body)
                    
                    Divider()
                    
                    Text("English Translation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .bold()
                    Text(translatedText)
                        .font(.body)
                }
                .padding()
            }
            .frame(width: 250, height: 180)
        }
    }
    
    /// Dynamically scales font size based on bounding box constraints
    private func calculateFontSize(width: CGFloat, height: CGFloat) -> CGFloat {
        let area = width * height
        if area < 100 {
            return 8
        } else if area < 400 {
            return 10
        } else if area < 1000 {
            return 12
        } else if height < 15 {
            return 9
        } else {
            return min(14, max(8, height * 0.7))
        }
    }
}
