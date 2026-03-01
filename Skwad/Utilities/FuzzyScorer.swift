import Foundation

/// VSCode-style fuzzy file matching algorithm.
/// Based on the algorithm from https://github.com/D0ntPanic/code-fuzzy-match
/// which is a faithful port of VSCode's fuzzy matching.
enum FuzzyScorer {

    struct ScoredMatch {
        let score: Int
        let matchedIndices: [Int]
    }

    // MARK: - Scoring Constants (from VSCode)

    private static let baseMatchScore = 1
    private static let sameCaseBonus = 1
    private static let startOfTargetBonus = 8
    private static let endOfTargetBonus = 2
    private static let pathSeparatorBonus = 5
    private static let wordSeparatorBonus = 4
    private static let wordStartBonus = 2   // after separator or camelCase boundary
    private static let sequentialBonusMultiplier = 5
    private static let filenameBonus = 10
    private static let filenameExactBonus = 50  // pattern matches filename stem exactly (case-insensitive)

    private static let separators: Set<Character> = ["_", "-", ".", " ", "'", "\"", ":"]

    // MARK: - Public API

    /// Quick pre-check: are all pattern characters present in target in order?
    static func isPatternInWord(pattern: String, target: String) -> Bool {
        guard !pattern.isEmpty else { return true }
        guard !target.isEmpty else { return false }

        let patternLower = pattern.lowercased()
        let targetLower = target.lowercased()

        var pi = patternLower.startIndex
        for tc in targetLower {
            if tc == patternLower[pi] {
                pi = patternLower.index(after: pi)
                if pi == patternLower.endIndex { return true }
            }
        }
        return false
    }

    /// Full fuzzy score using VSCode-style DP. Returns nil if pattern doesn't match target.
    static func score(pattern: String, target: String) -> ScoredMatch? {
        guard !pattern.isEmpty else { return ScoredMatch(score: 0, matchedIndices: []) }
        guard !target.isEmpty else { return nil }
        guard isPatternInWord(pattern: pattern, target: target) else { return nil }

        let patternChars = Array(pattern)
        let targetChars = Array(target)
        let m = patternChars.count
        let n = targetChars.count

        guard m <= n else { return nil }

        // DP state: for each query char, track score and sequential match count
        // across the target. We only need the previous row and current row.
        var prevScore = [Int](repeating: 0, count: n)
        var prevSeqCount = [Int](repeating: 0, count: n)
        var currScore = [Int](repeating: 0, count: n)
        var currSeqCount = [Int](repeating: 0, count: n)

        // Track match decisions for backtracking
        var matchTable = [[Bool]](repeating: [Bool](repeating: false, count: n), count: m)

        var firstQueryChar = true

        for qi in 0..<m {
            currScore = [Int](repeating: 0, count: n)
            currSeqCount = [Int](repeating: 0, count: n)

            for ti in 0..<n {
                let pChar = patternChars[qi]
                let tChar = targetChars[ti]

                // Score propagated from the previous target position (skip this target char)
                let prevTargetScore = ti > 0 ? currScore[ti - 1] : 0

                // Score from matching previous query char at previous target position (diagonal)
                let prevQueryScore = ti > 0 ? prevScore[ti - 1] : 0
                let seqMatchCount = ti > 0 ? prevSeqCount[ti - 1] : 0

                // If not the first query char and there's no prior query score, skip
                if !firstQueryChar && prevQueryScore == 0 {
                    currScore[ti] = prevTargetScore
                    continue
                }

                // Check character match (case-insensitive)
                guard pChar.lowercased() == tChar.lowercased() else {
                    currScore[ti] = prevTargetScore
                    continue
                }

                // Compute score for this character match
                var charScore = baseMatchScore

                // Sequential match bonus
                charScore += seqMatchCount * sequentialBonusMultiplier

                // Same case bonus
                if pChar == tChar {
                    charScore += sameCaseBonus
                }

                // Position bonuses
                if ti == 0 {
                    charScore += startOfTargetBonus
                } else {
                    let prevTChar = targetChars[ti - 1]
                    if prevTChar == "/" || prevTChar == "\\" {
                        charScore += pathSeparatorBonus
                    } else if separators.contains(prevTChar) {
                        charScore += wordSeparatorBonus
                    } else if seqMatchCount == 0 {
                        // Word start bonus: after separator or camelCase
                        if separators.contains(prevTChar) {
                            charScore += wordStartBonus
                        } else if tChar.isUppercase {
                            charScore += wordStartBonus
                        }
                    }
                }

                // End of target bonus
                if ti == n - 1 {
                    charScore += endOfTargetBonus
                }

                let newScore = prevQueryScore + charScore
                if newScore >= prevTargetScore {
                    currScore[ti] = newScore
                    currSeqCount[ti] = seqMatchCount + 1
                    matchTable[qi][ti] = true
                } else {
                    currScore[ti] = prevTargetScore
                }
            }

            prevScore = currScore
            prevSeqCount = currSeqCount
            firstQueryChar = false
        }

        // Final score is at the last position
        let finalScore = prevScore[n - 1]
        guard finalScore > 0 else { return nil }

        // Backtrack to find matched indices
        var indices = [Int]()
        var qi = m - 1
        var ti = n - 1
        while qi >= 0 && ti >= 0 {
            if matchTable[qi][ti] {
                indices.append(ti)
                qi -= 1
                ti -= 1
            } else {
                ti -= 1
            }
            if ti < 0 { break }
        }
        indices.reverse()

        guard indices.count == m else { return nil }

        return ScoredMatch(score: finalScore, matchedIndices: indices)
    }

    /// Score a file path, with bonus for filename-only matches.
    static func scoreFile(pattern: String, path: String) -> ScoredMatch? {
        guard !pattern.isEmpty else { return nil }

        // Score against full path
        let fullMatch = score(pattern: pattern, target: path)

        // Score against filename only
        let filename = (path as NSString).lastPathComponent
        let filenameMatch = score(pattern: pattern, target: filename)

        // Adjust filename match indices to be relative to full path
        var adjustedFilenameMatch: ScoredMatch?
        if let fm = filenameMatch {
            let offset = path.count - filename.count
            let adjustedIndices = fm.matchedIndices.map { $0 + offset }

            // Extra bonus if pattern matches the filename stem exactly (case-insensitive)
            let stem = (filename as NSString).deletingPathExtension
            let exactStemMatch = stem.lowercased() == pattern.lowercased()

            // Earlier first occurrence of pattern start in filename gets a small bonus (tiebreaker)
            let firstChar = pattern.lowercased().first!
            let firstCharPos = filename.lowercased().firstIndex(of: firstChar)
                .map { filename.distance(from: filename.startIndex, to: $0) } ?? 0
            let positionBonus = max(0, 5 - firstCharPos)

            adjustedFilenameMatch = ScoredMatch(
                score: fm.score + filenameBonus + positionBonus + (exactStemMatch ? filenameExactBonus : 0),
                matchedIndices: adjustedIndices
            )
        }

        // Return the better match
        switch (fullMatch, adjustedFilenameMatch) {
        case (nil, nil): return nil
        case (let f?, nil): return f
        case (nil, let a?): return a
        case (let f?, let a?): return f.score >= a.score ? f : a
        }
    }
}
