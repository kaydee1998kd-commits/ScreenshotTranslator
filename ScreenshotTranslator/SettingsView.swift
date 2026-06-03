import SwiftUI

struct SettingsView: View {
    @ObservedObject var photoManager: PhotoLibraryManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var provider: TranslationProvider = .myMemory
    @State private var googleKey: String = ""
    @State private var deepLKey: String = ""
    @State private var isDeepLPro: Bool = false
    
    private let translationService = TranslationService()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Translation Service")) {
                    Picker("Provider", selection: $provider) {
                        ForEach(TranslationProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .onChange(of: provider) { newValue in
                        translationService.selectedProvider = newValue
                    }
                    
                    if provider == .myMemory {
                        Text("MyMemory provides up to 5,000 characters/day for free without any configuration. No registration or API key required.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if provider == .google {
                    Section(header: Text("Google Cloud Translate API")) {
                        SecureField("API Key", text: $googleKey)
                            .onChange(of: googleKey) { newValue in
                                translationService.googleApiKey = newValue
                            }
                        
                        Link(destination: URL(string: "https://cloud.google.com/translate/docs/setup")!) {
                            HStack {
                                Text("Get Google API Key")
                                Spacer()
                                Image(systemName: "arrow.up.forward.app")
                            }
                            .font(.footnote)
                        }
                    }
                }
                
                if provider == .deepL {
                    Section(header: Text("DeepL API Config")) {
                        SecureField("API Key", text: $deepLKey)
                            .onChange(of: deepLKey) { newValue in
                                translationService.deepLApiKey = newValue
                            }
                        
                        Toggle("Use DeepL Pro Endpoint", isOn: $isDeepLPro)
                            .onChange(of: isDeepLPro) { newValue in
                                translationService.isDeepLPro = newValue
                            }
                            .font(.subheadline)
                        
                        Text("Toggle on if your API key belongs to a paid DeepL Pro account instead of a free developer account.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Link(destination: URL(string: "https://www.deepl.com/pro-api")!) {
                            HStack {
                                Text("Get DeepL API Key")
                                Spacer()
                                Image(systemName: "arrow.up.forward.app")
                            }
                            .font(.footnote)
                        }
                    }
                }
                
                Section(header: Text("Photos Permissions")) {
                    HStack {
                        Text("Access Status")
                        Spacer()
                        Text(permissionStatusString)
                            .foregroundColor(photoManager.authorizationStatus == .authorized || photoManager.authorizationStatus == .limited ? .green : .orange)
                            .bold()
                    }
                    
                    if photoManager.authorizationStatus == .denied || photoManager.authorizationStatus == .restricted {
                        Button(action: openSystemSettings) {
                            Text("Open iOS System Settings")
                                .font(.subheadline)
                        }
                    }
                }
                
                Section(header: Text("About App")) {
                    HStack {
                        Text("Target OS")
                        Spacer()
                        Text("iOS 15.0+")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Compatibility")
                        Spacer()
                        Text("iPhone 6s/7/SE (iOS 15.8.5)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0.0 (Release)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                // Initialize form values from UserDefaults
                provider = translationService.selectedProvider
                googleKey = translationService.googleApiKey
                deepLKey = translationService.deepLApiKey
                isDeepLPro = translationService.isDeepLPro
                photoManager.checkStatus()
            }
        }
    }
    
    private var permissionStatusString: String {
        switch photoManager.authorizationStatus {
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        case .limited: return "Limited Access"
        @unknown default: return "Unknown"
        }
    }
    
    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}
