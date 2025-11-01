import CryptoKit
import Foundation

extension Data {
    func sha256Hex() -> String {
        let digest = SHA256.hash(data: self)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
