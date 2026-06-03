import Foundation

enum TranslationProvider: String, CaseIterable, Identifiable {
    case myMemory = "MyMemory (Free, Keyless)"
    case google = "Google Translate"
    case deepL = "DeepL"
    
    var id: String { self.rawValue }
}

class TranslationService {
    
    // Keys for UserDefaults
    private let providerKey = "com.artkd.translator.provider"
    private let googleKeyKey = "com.artkd.translator.googleKey"
    private let deepLKeyKey = "com.artkd.translator.deepLKey"
    private let deepLProKey = "com.artkd.translator.deepLPro"
    
    var selectedProvider: TranslationProvider {
        get {
            if let value = UserDefaults.standard.string(forKey: providerKey),
               let provider = TranslationProvider(rawValue: value) {
                return provider
            }
            return .myMemory
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: providerKey)
        }
    }
    
    var googleApiKey: String {
        get { UserDefaults.standard.string(forKey: googleKeyKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: googleKeyKey) }
    }
    
    var deepLApiKey: String {
        get { UserDefaults.standard.string(forKey: deepLKeyKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: deepLKeyKey) }
    }
    
    var isDeepLPro: Bool {
        get { UserDefaults.standard.bool(forKey: deepLProKey) }
        set { UserDefaults.standard.set(newValue, forKey: deepLProKey) }
    }
    
    /// Translates an array of TextBlocks from Chinese to English.
    func translate(blocks: [TextBlock]) async throws -> [TextBlock] {
        guard !blocks.isEmpty else { return [] }
        
        switch selectedProvider {
        case .myMemory:
            return try await translateWithMyMemory(blocks: blocks)
        case .google:
            return try await translateWithGoogle(blocks: blocks)
        case .deepL:
            return try await translateWithDeepL(blocks: blocks)
        }
    }
    
    // MARK: - MyMemory Translator (Sequential / Keyless)
    private func translateWithMyMemory(blocks: [TextBlock]) async throws -> [TextBlock] {
        var translatedBlocks: [TextBlock] = []
        
        for block in blocks {
            let textToTranslate = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if textToTranslate.isEmpty {
                translatedBlocks.append(block)
                continue
            }
            
            // Check if text contains Chinese characters. If it's English, don't translate it.
            if !containsChinese(textToTranslate) {
                var updated = block
                updated.translatedText = textToTranslate
                translatedBlocks.append(updated)
                continue
            }
            
            guard let encodedText = textToTranslate.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                translatedBlocks.append(block)
                continue
            }
            
            let urlString = "https://api.mymemory.translated.net/get?q=\(encodedText)&langpair=zh-CN|en"
            guard let url = URL(string: urlString) else {
                translatedBlocks.append(block)
                continue
            }
            
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    var updated = block
                    updated.translatedText = "[Error: Translation failed]"
                    translatedBlocks.append(updated)
                    continue
                }
                
                struct MyMemoryResponse: Codable {
                    struct ResponseData: Codable {
                        let translatedText: String
                    }
                    let responseData: ResponseData
                    let responseStatus: Int
                }
                
                let result = try JSONDecoder().decode(MyMemoryResponse.self, from: data)
                var updated = block
                if result.responseStatus == 200 {
                    updated.translatedText = result.responseData.translatedText
                } else {
                    updated.translatedText = "[Limit/Error \(result.responseStatus)]"
                }
                translatedBlocks.append(updated)
                
                // Add a small delay between requests to avoid hitting MyMemory rate limits
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            } catch {
                var updated = block
                updated.translatedText = "[Connection Error]"
                translatedBlocks.append(updated)
            }
        }
        
        return translatedBlocks
    }
    
    // MARK: - Google Translate API (Batch POST)
    private func translateWithGoogle(blocks: [TextBlock]) async throws -> [TextBlock] {
        let apiKey = googleApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw NSError(domain: "TranslationService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Google Translate API Key is missing. Please configure it in Settings."])
        }
        
        let urlString = "https://translation.googleapis.com/language/translate/v2?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "TranslationService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid Google API URL."])
        }
        
        // Filter out non-Chinese blocks or empty blocks, but keep track of indices
        var indicesToTranslate: [Int] = []
        var textsToTranslate: [String] = []
        
        for (index, block) in blocks.enumerated() {
            let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty && containsChinese(text) {
                indicesToTranslate.append(index)
                textsToTranslate.append(text)
            }
        }
        
        var resultBlocks = blocks
        
        // Set English translations for non-Chinese blocks immediately
        for (index, block) in blocks.enumerated() {
            if !containsChinese(block.text) {
                resultBlocks[index].translatedText = block.text
            }
        }
        
        guard !textsToTranslate.isEmpty else {
            return resultBlocks
        }
        
        // Construct JSON Request
        let requestBody: [String: Any] = [
            "q": textsToTranslate,
            "target": "en",
            "source": "zh"
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown HTTP error"
            throw NSError(domain: "TranslationService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Google API error: \(errorMsg)"])
        }
        
        struct GoogleTranslateResponse: Codable {
            struct DataContainer: Codable {
                struct Translation: Codable {
                    let translatedText: String
                }
                let translations: [Translation]
            }
            let data: DataContainer
        }
        
        let result = try JSONDecoder().decode(GoogleTranslateResponse.self, from: data)
        let translations = result.data.translations
        
        for (idx, originalIndex) in indicesToTranslate.enumerated() {
            if idx < translations.count {
                resultBlocks[originalIndex].translatedText = htmlDecode(translations[idx].translatedText)
            }
        }
        
        return resultBlocks
    }
    
    // MARK: - DeepL Translate API (Batch POST)
    private func translateWithDeepL(blocks: [TextBlock]) async throws -> [TextBlock] {
        let apiKey = deepLApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw NSError(domain: "TranslationService", code: 4, userInfo: [NSLocalizedDescriptionKey: "DeepL API Key is missing. Please configure it in Settings."])
        }
        
        let host = isDeepLPro ? "api.deepl.com" : "api-free.deepl.com"
        let urlString = "https://\(host)/v2/translate"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "TranslationService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid DeepL API URL."])
        }
        
        var indicesToTranslate: [Int] = []
        var textsToTranslate: [String] = []
        
        for (index, block) in blocks.enumerated() {
            let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty && containsChinese(text) {
                indicesToTranslate.append(index)
                textsToTranslate.append(text)
            }
        }
        
        var resultBlocks = blocks
        
        for (index, block) in blocks.enumerated() {
            if !containsChinese(block.text) {
                resultBlocks[index].translatedText = block.text
            }
        }
        
        guard !textsToTranslate.isEmpty else {
            return resultBlocks
        }
        
        // Construct JSON Request
        let requestBody: [String: Any] = [
            "text": textsToTranslate,
            "target_lang": "EN"
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("DeepL-Auth-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown HTTP error"
            throw NSError(domain: "TranslationService", code: 6, userInfo: [NSLocalizedDescriptionKey: "DeepL API error: \(errorMsg)"])
        }
        
        struct DeepLTranslateResponse: Codable {
            struct Translation: Codable {
                let detected_source_language: String
                let text: String
            }
            let translations: [Translation]
        }
        
        let result = try JSONDecoder().decode(DeepLTranslateResponse.self, from: data)
        let translations = result.translations
        
        for (idx, originalIndex) in indicesToTranslate.enumerated() {
            if idx < translations.count {
                resultBlocks[originalIndex].translatedText = translations[idx].text
            }
        }
        
        return resultBlocks
    }
    
    // MARK: - Utility Methods
    
    /// Detects if a string contains any Chinese characters (Unicode script: Han)
    private func containsChinese(_ text: String) -> Bool {
        return text.range(of: "\\p{Script=Han}", options: .regularExpression) != nil
    }
    
    /// Basic HTML character decoder (since Google Translate returns HTML entities like &#39; or &quot;)
    private func htmlDecode(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return string }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attributedString.string
        }
        return string
    }
}
