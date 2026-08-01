import UniformTypeIdentifiers

enum AudioImportContentTypes {
    static let all: [UTType] = AudioFormat.supportedExtensions.reduce(into: []) { types, fileExtension in
        guard let type = UTType(filenameExtension: fileExtension),
              !types.contains(type) else { return }
        types.append(type)
    }
}
