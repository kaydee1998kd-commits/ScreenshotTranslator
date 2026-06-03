import SwiftUI
import Photos
import PhotosUI

struct ContentView: View {
    @StateObject private var photoManager = PhotoLibraryManager()
    
    @State private var selectedImage: UIImage? = nil
    @State private var navigateToTranslation = false
    
    @State private var recentScreenshot: PHAsset? = nil
    @State private var showRecentBanner = false
    
    @State private var showSettings = false
    @State private var showPicker = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                // Active Navigation Link to Detail Page
                if let img = selectedImage {
                    NavigationLink(
                        destination: TranslationView(inputImage: img),
                        isActive: $navigateToTranslation
                    ) {
                        EmptyView()
                    }
                }
                
                switch photoManager.authorizationStatus {
                case .notDetermined:
                    permissionRequestView
                case .denied, .restricted:
                    permissionDeniedView
                case .authorized, .limited:
                    mainDashboardView
                @unknown default:
                    permissionRequestView
                }
            }
            .navigationTitle("Screenshot Translator")
            .navigationBarItems(
                leading: Image(systemName: "translate")
                    .foregroundColor(.accentColor)
                    .font(.headline),
                trailing: Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
            )
            .sheet(isPresented: $showSettings) {
                SettingsView(photoManager: photoManager)
            }
            .sheet(isPresented: $showPicker) {
                PhotoPicker(selectedImage: $selectedImage, isPresented: $showPicker)
                    .ignoresSafeArea()
            }
            .onChange(of: selectedImage) { newImage in
                if newImage != nil {
                    navigateToTranslation = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Check permissions and scan for screenshots when app comes back to foreground
                photoManager.checkStatus()
                checkForRecentScreenshot()
            }
            .onAppear {
                checkForRecentScreenshot()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Subviews
    
    private var permissionRequestView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
            }
            
            VStack(spacing: 8) {
                Text("Access Photo Library")
                    .font(.title2)
                    .bold()
                Text("We need permission to read your screenshots and display them so you can translate Chinese text on them.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button(action: {
                photoManager.requestAccess { granted in
                    if granted {
                        checkForRecentScreenshot()
                    }
                }
            }) {
                Text("Grant Photos Access")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(12)
                    .padding(.horizontal, 40)
            }
        }
        .padding()
    }
    
    private var permissionDeniedView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "photo.fill.on.rectangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
            }
            
            VStack(spacing: 8) {
                Text("Photos Permission Required")
                    .font(.title2)
                    .bold()
                Text("Photos permission is currently denied or restricted. Please enable Photos access in your system settings to translate screenshots.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button(action: openSystemSettings) {
                Text("Open Settings")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(12)
                    .padding(.horizontal, 40)
            }
        }
        .padding()
    }
    
    private var mainDashboardView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Auto-Detect Recent Screenshot Alert Banner
                if showRecentBanner, let asset = recentScreenshot {
                    recentScreenshotBanner(for: asset)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Main Operations Card
                operationCard
                
                // Screenshot Albums Grid
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Screenshots")
                        .font(.headline)
                        .padding(.horizontal, 4)
                    
                    if photoManager.screenshots.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary)
                            Text("No screenshots found")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(height: 150)
                        .frame(maxWidth: .infinity)
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(12)
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(photoManager.screenshots, id: \.localIdentifier) { asset in
                                Button(action: {
                                    loadAssetAndNavigate(asset)
                                }) {
                                    PHAssetThumbnailView(asset: asset, manager: photoManager)
                                        .frame(height: 110)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.black.opacity(0.05), lineWidth: 1)
                                        )
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .onAppear {
            photoManager.fetchScreenshots()
        }
    }
    
    private var operationCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles.text.rectangle")
                .font(.system(size: 32))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 4) {
                Text("Select Any Image to Translate")
                    .font(.subheadline)
                    .bold()
                Text("You can translate any image containing Chinese from your entire photo library.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            
            Button(action: { showPicker = true }) {
                HStack {
                    Image(systemName: "photo.badge.plus")
                    Text("Choose Photo...")
                }
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.accentColor)
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.02), radius: 3, x: 0, y: 1)
    }
    
    private func recentScreenshotBanner(for asset: PHAsset) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                PHAssetThumbnailView(asset: asset, manager: photoManager)
                    .frame(width: 50, height: 70)
                    .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("New Screenshot Found!")
                        .font(.subheadline)
                        .bold()
                    Text("Taken in the last 15 minutes. Would you like to translate it from Chinese to English?")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        showRecentBanner = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }
            
            Button(action: {
                loadAssetAndNavigate(asset)
                withAnimation {
                    showRecentBanner = false
                }
            }) {
                HStack {
                    Image(systemName: "translate")
                    Text("Translate Immediately")
                }
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Helper Methods
    
    private func checkForRecentScreenshot() {
        photoManager.detectRecentScreenshot(maxAgeSeconds: 900) { asset in
            if let asset = asset {
                withAnimation {
                    self.recentScreenshot = asset
                    self.showRecentBanner = true
                }
            } else {
                withAnimation {
                    self.recentScreenshot = nil
                    self.showRecentBanner = false
                }
            }
        }
    }
    
    private func loadAssetAndNavigate(_ asset: PHAsset) {
        photoManager.loadImage(for: asset) { image in
            if let image = image {
                self.selectedImage = image
            }
        }
    }
    
    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

// Subview representing thumbnail loading in LazyVGrid
struct PHAssetThumbnailView: View {
    let asset: PHAsset
    let manager: PhotoLibraryManager
    @State private var thumbnail: UIImage? = nil
    
    var body: some View {
        ZStack {
            if let img = thumbnail {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                ProgressView()
            }
        }
        .onAppear {
            manager.loadImage(for: asset, targetSize: CGSize(width: 150, height: 150)) { image in
                self.thumbnail = image
            }
        }
    }
}

// Representable wrapping PHPickerViewController
struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.isPresented = false
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, error in
                    if let uiImage = image as? UIImage {
                        DispatchQueue.main.async {
                            self.parent.selectedImage = uiImage
                        }
                    }
                }
            }
        }
    }
}
