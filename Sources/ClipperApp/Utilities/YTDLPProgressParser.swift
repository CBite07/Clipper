import Foundation

struct YTDLPProgressParser {
    private static let progressRegularExpression = try? NSRegularExpression(
        pattern: "(?:(?:\[download\]\s+)|(?:\s))(?:(\d{1,3}\.\d)%).*?ETA\s+([\d:]+)",
        options: [.dotMatchesLineSeparators]
    )

    static func parseProgress(from line: String) -> (progress: Double, eta: TimeInterval?)? {
        guard let regex = progressRegularExpression else { return nil }
        let range = NSRange(location: 0, length: line.utf16.count)
        guard let match = regex.firstMatch(in: line, options: [], range: range) else { return nil }

        var extractedProgress: Double?
        var etaValue: TimeInterval?

        if match.numberOfRanges > 1,
           let progressRange = Range(match.range(at: 1), in: line) {
            extractedProgress = Double(line[progressRange])
        }

        if match.numberOfRanges > 2,
           let etaRange = Range(match.range(at: 2), in: line) {
            etaValue = timeInterval(for: String(line[etaRange]))
        }

        guard let progress = extractedProgress else { return nil }
        return (progress / 100.0, etaValue)
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
