import Foundation

struct YTDLPProgressParser {
    static func parseProgress(from line: String) -> (progress: Double, eta: TimeInterval?)? {
        let tokens = line.split { $0.isWhitespace }

        guard let percentToken = tokens.first(where: { $0.hasSuffix("%") }),
              let progressValue = Double(percentToken.dropLast()) else {
            return nil
        }

        var etaValue: TimeInterval?
        if let etaIndex = tokens.firstIndex(where: { $0 == "ETA" }) {
            let nextIndex = tokens.index(after: etaIndex)
            if nextIndex < tokens.endIndex {
                etaValue = timeInterval(for: String(tokens[nextIndex]))
            }
        }

        return (progressValue / 100.0, etaValue)
    }

    private static func timeInterval(for etaString: String) -> TimeInterval? {
        let components = etaString.split(separator: ":").compactMap { Double($0) }
        guard !components.isEmpty else { return nil }
        let reversed = components.reversed()
        var multiplier: Double = 1
        var total: Double = 0
        for value in reversed {
            total += value * multiplier
            multiplier *= 60
        }
        return total
    }
}
