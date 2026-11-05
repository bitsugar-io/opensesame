import Foundation

public struct HintConfiguration: Equatable {
    // Vimium's default avoids ambiguous V/Y and I/O/Q lookalikes.
    public static let defaultAlphabet = "sadfjklewcmpgh"
    public static let legacyAlphabet = "asdfghjklqwertyuiopzxcvbnm"
    public static let standard = try! HintConfiguration()
    public let minimumLength: Int
    public let alphabet: String
    public let prefix: String

    public init(minimumLength: Int = 2, alphabet: String = Self.defaultAlphabet, prefix: String = "") throws {
        guard (1...3).contains(minimumLength) else { throw ValidationError("Choose 1, 2, or 3 letters.") }
        func isLetter(_ c: Character) -> Bool { c.isASCII && (c.isLowercase || c.isUppercase) }
        guard alphabet.allSatisfy(isLetter), alphabet.count >= 2,
              Set(alphabet.lowercased()).count == alphabet.count else {
            throw ValidationError("Use at least two different letters, A–Z, with no spaces or repeats.")
        }
        guard prefix.count <= 3, prefix.allSatisfy(isLetter) else { throw ValidationError("The optional prefix can contain up to three letters, A–Z.") }
        self.minimumLength = minimumLength
        self.alphabet = alphabet.lowercased()
        self.prefix = prefix.lowercased()
    }
    public struct ValidationError: LocalizedError {
        public let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }
}
