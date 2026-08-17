import Foundation

/// Resolves managed-library URLs after iOS changes the app container path.
enum ManagedMediaURLResolver {
    static func resolveAvailableURL(
        _ persistedURL: URL,
        fileManager: FileManager = .default,
        documentsDirectory: URL? = nil
    ) -> URL? {
        guard persistedURL.isFileURL else { return nil }

        let standardizedURL = persistedURL.standardizedFileURL
        if fileManager.fileExists(atPath: standardizedURL.path) {
            return standardizedURL
        }

        guard let relativeComponents = managedLibraryRelativeComponents(in: standardizedURL),
              let currentDocumentsDirectory = documentsDirectory
                ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        else {
            return nil
        }

        let musicDirectory = FileSystemService.managedMediaRoot(
            for: currentDocumentsDirectory
        )
        let candidate = relativeComponents.reduce(musicDirectory) { partialURL, component in
            partialURL.appendingPathComponent(component)
        }.standardizedFileURL

        guard FileSystemService.isLibraryManaged(
            candidate,
            under: currentDocumentsDirectory
        ),
              fileManager.fileExists(atPath: candidate.path)
        else {
            return nil
        }

        return candidate
    }

    private static func managedLibraryRelativeComponents(in url: URL) -> ArraySlice<String>? {
        let components = url.pathComponents
        guard components.count >= 3 else { return nil }

        for documentsIndex in components.indices.reversed()
        where components[documentsIndex] == "Documents" {
            let musicIndex = components.index(after: documentsIndex)
            guard musicIndex < components.endIndex,
                  components[musicIndex] == "Music"
            else {
                continue
            }

            let firstRelativeIndex = components.index(after: musicIndex)
            guard firstRelativeIndex < components.endIndex else { return nil }
            return components[firstRelativeIndex...]
        }

        return nil
    }
}
