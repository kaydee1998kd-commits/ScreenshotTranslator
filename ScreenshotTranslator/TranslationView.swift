import SwiftUI
import Photos

struct TranslationView: View {
    let inputImage: UIImage
    @Environment(\.presentationMode) var presentationMode
    
    @State private var ocrBlocks: [TextBlock] = []
    @State private var translationState: TranslationState = .idle
    @State private var selectedTab = 0 // 0: Overlay, 1: Split List
    @State private var maskOpacity: Double = 0.9
    @State private var showOverlays = true
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var alertMessage = ""
    @State private var showAlert = false
    
    private let ocrService = OCRService()
    private let translationService = TranslationService()
    
    enum TranslationState: Equatable {
        case idle
        case processingOCR
        case translating
        case success
        case failed(String)
        
        var stepText: String {
            switch self {
            case .idle: return "Initializing..."
            case .processingOCR: return "Analyzing image & extracting Chinese text..."
            case .translating: return "Translating Chinese text to English..."
            case .success: return "Done!"
            case .failed(let err): return "Failed: \(err)"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar
            
            // Main Content Area
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                switch translationState {
                case .idle, .processingOCR, .translating:
                    loadingView
                case .success:
                    if ocrBlocks.isEmpty {
                        noTextFoundView
                    } else if selectedTab == 0 {
                        overlayDisplayView
                    } else {
                        splitListView
                    }
                case .failed(let error):
                    errorView(error: error)
                }
            }
            
            // Bottom Action Bar
            if translationState == .success && !ocrBlocks.isEmpty {
                bottomActionBar
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            startPipeline()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Notice"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    // MARK: - Subviews
    
    private var headerBar: some View {
        HStack {
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Back")
                }
                .foregroundColor(.accentColor)
            }
            
            Spacer()
            
            if translationState == .success && !ocrBlocks.isEmpty {
                Picker("Display", selection: $selectedTab) {
                    Text("Overlay").tag(0)
                    Text("List").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 180)
            } else {
                Text("Translation")
                    .font(.headline)
            }
            
            Spacer()
            
            // Alignment placeholder or Refresh Button
            Button(action: {
                startPipeline()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 18))
                    .foregroundColor(translationState == .success ? .accentColor : .secondary)
            }
            .disabled(translationState == .processingOCR || translationState == .translating)
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle())
            
            Text(translationState.stepText)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .systemBackground))
                .shadow(radius: 10)
        )
        .padding()
    }
    
    private var noTextFoundView: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            Text("No Chinese Text Detected")
                .font(.title3)
                .bold()
            Text("We couldn't detect any Chinese characters in this screenshot. Please make sure the text is clear and readable.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding()
    }
    
    private var overlayDisplayView: some View {
        VStack(spacing: 0) {
            // Interactive Image Area
            ZStack {
                Image(uiImage: inputImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .background(Color.black.opacity(0.05))
                
                TranslationOverlayView(
                    image: inputImage,
                    blocks: ocrBlocks,
                    maskOpacity: maskOpacity,
                    showOverlays: showOverlays
                )
            }
            .padding()
            
            // Opacity & Overlay Controls Card
            VStack(spacing: 12) {
                HStack {
                    Toggle("Show Translations", isOn: $showOverlays)
                        .font(.subheadline.weight(.bold))
                    
                    Spacer()
                }
                
                if showOverlays {
                    HStack(spacing: 16) {
                        Image(systemName: "eye.slash.fill")
                            .foregroundColor(.secondary)
                            .font(.footnote)
                        
                        Slider(value: $maskOpacity, in: 0...1.0)
                            .accentColor(.accentColor)
                        
                        Image(systemName: "eye.fill")
                            .foregroundColor(.secondary)
                            .font(.footnote)
                    }
                    
                    Text("Adjust mask opacity to see underlying text")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    private var splitListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(ocrBlocks) { block in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Original (ZH)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .bold()
                            Spacer()
                            Button(action: {
                                UIPasteboard.general.string = block.text
                                triggerHapticFeedback()
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.footnote)
                                    .foregroundColor(.accentColor)
                            }
                        }
                        
                        Text(block.text)
                            .font(.body)
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                        
                        Divider()
                        
                        HStack {
                            Text("Translation (EN)")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                                .bold()
                            Spacer()
                            if let translated = block.translatedText {
                                Button(action: {
                                    UIPasteboard.general.string = translated
                                    triggerHapticFeedback()
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.footnote)
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        
                        if let translated = block.translatedText {
                            Text(translated)
                                .font(.body)
                                .bold()
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                        } else {
                            Text("Translating...")
                                .font(.body)
                                .italic()
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .systemBackground))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.02), radius: 2, x: 0, y: 1)
                }
            }
            .padding()
        }
    }
    
    private func errorView(error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text("Translation Interrupted")
                .font(.headline)
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            
            Button(action: {
                startPipeline()
            }) {
                Text("Retry Connection")
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .systemBackground))
                .shadow(radius: 6)
        )
        .padding()
    }
    
    private var bottomActionBar: some View {
        HStack(spacing: 16) {
            // Share Image
            Button(action: shareTranslatedImage) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Image")
                }
                .font(.subheadline.weight(.bold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(10)
            }
            
            // Save Image
            Button(action: saveTranslatedImage) {
                HStack {
                    Image(systemName: "arrow.down.to.line")
                    Text("Save to Photos")
                }
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: -2)
    }
    
    // MARK: - Business Logic Pipeline
    
    private func startPipeline() {
        ocrBlocks = []
        translationState = .processingOCR
        
        ocrService.performOCR(on: inputImage) { result in
            switch result {
            case .success(let blocks):
                if blocks.isEmpty {
                    DispatchQueue.main.async {
                        self.ocrBlocks = []
                        self.translationState = .success
                    }
                } else {
                    DispatchQueue.main.async {
                        self.ocrBlocks = blocks
                        self.translationState = .translating
                    }
                    self.performTranslation(for: blocks)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.translationState = .failed("OCR Failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func performTranslation(for blocks: [TextBlock]) {
        Task {
            do {
                let translated = try await translationService.translate(blocks: blocks)
                DispatchQueue.main.async {
                    self.ocrBlocks = translated
                    self.translationState = .success
                }
            } catch {
                DispatchQueue.main.async {
                    self.translationState = .failed(error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Image Rendering & Sharing
    
    private func generateOutputImage() -> UIImage? {
        let size = inputImage.size
        
        // Setup image drawing context
        UIGraphicsBeginImageContextWithOptions(size, true, inputImage.scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // Draw original screenshot
        inputImage.draw(in: CGRect(origin: .zero, size: size))
        
        // Draw text blocks
        for block in ocrBlocks {
            guard let translated = block.translatedText, !translated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            
            // Calculate absolute layout in image space
            let w = block.boundingBox.size.width * size.width
            let h = block.boundingBox.size.height * size.height
            let x = block.boundingBox.origin.x * size.width
            
            // CoreGraphics coordinate origin is bottom-left, but UIKit drawing uses top-left origin.
            // When drawing images/text in UIKit context, it maps to top-left.
            let y = (1.0 - block.boundingBox.origin.y - block.boundingBox.size.height) * size.height
            let rect = CGRect(x: x, y: y, width: w, height: h)
            
            // Draw opaque background mask
            context.setFillColor(UIColor.systemBackground.cgColor)
            context.fill(rect)
            
            // Draw English Text
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            let fontSize = calculateOptimalFontSize(height: h)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraphStyle
            ]
            
            let attributedString = NSAttributedString(string: translated, attributes: attributes)
            
            // Vertically center the text inside the box
            let textHeight = attributedString.boundingRect(with: CGSize(width: w, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil).height
            let textY = y + max(0, (h - textHeight) / 2.0)
            let drawRect = CGRect(x: x, y: textY, width: w, height: textHeight)
            
            attributedString.draw(in: drawRect)
        }
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    private func calculateOptimalFontSize(height: CGFloat) -> CGFloat {
        if height < 12 {
            return 9
        } else if height < 18 {
            return 11
        } else if height < 30 {
            return 14
        } else {
            return min(24, height * 0.6)
        }
    }
    
    private func shareTranslatedImage() {
        guard let output = generateOutputImage() else {
            self.alertMessage = "Unable to render translated image."
            self.showAlert = true
            return
        }
        
        self.shareItems = [output]
        self.showShareSheet = true
    }
    
    private func saveTranslatedImage() {
        guard let output = generateOutputImage() else {
            self.alertMessage = "Unable to render translated image."
            self.showAlert = true
            return
        }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: output)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.alertMessage = "Successfully saved translation to Photos!"
                    self.showAlert = true
                } else if let error = error {
                    self.alertMessage = "Failed to save: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }
    
    private func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// UIKit UIActivityViewController wrapper for SwiftUI
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        return UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
