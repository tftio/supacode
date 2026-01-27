import Foundation

struct WorktreeInfoEntry: Equatable {
  var addedLines: Int?
  var removedLines: Int?
  var pullRequestNumber: Int?

  var descriptionText: String? {
    var parts: [String] = []
    if let addedLines, let removedLines {
      parts.append("+\(addedLines) -\(removedLines)")
    }
    if let pullRequestNumber {
      parts.append("PR: \(pullRequestNumber)")
    }
    return parts.isEmpty ? nil : parts.joined(separator: " ")
  }
}
