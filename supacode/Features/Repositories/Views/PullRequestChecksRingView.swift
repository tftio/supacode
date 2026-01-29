import SwiftUI

struct PullRequestChecksRingView: View {
  let breakdown: PullRequestCheckBreakdown
  @ScaledMetric(relativeTo: .caption) private var diameter: CGFloat = 12
  @ScaledMetric(relativeTo: .caption) private var lineWidth: CGFloat = 2

  var body: some View {
    if breakdown.total == 0 {
      EmptyView()
    } else {
      let segments = segments(for: breakdown)
      ZStack {
        ForEach(segments) { segment in
          RingSegmentShape(startAngle: segment.startAngle, endAngle: segment.endAngle)
            .stroke(segment.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
        }
      }
      .frame(width: diameter, height: diameter)
      .accessibilityHidden(true)
    }
  }

  private func segments(for breakdown: PullRequestCheckBreakdown) -> [Segment] {
    let total = Double(breakdown.total)
    guard total > 0 else {
      return []
    }
    var start = -90.0
    var segments: [Segment] = []
    func addSegment(id: String, count: Int, color: Color) {
      guard count > 0 else {
        return
      }
      let sweep = (Double(count) / total) * 360
      let end = start + sweep
      segments.append(
        Segment(
          id: id,
          startAngle: .degrees(start),
          endAngle: .degrees(end),
          color: color
        )
      )
      start = end
    }
    addSegment(id: "failed", count: breakdown.failed, color: .red)
    addSegment(id: "inProgress", count: breakdown.inProgress, color: .yellow)
    addSegment(id: "skipped", count: breakdown.skipped, color: .gray)
    addSegment(id: "expected", count: breakdown.expected, color: .yellow)
    addSegment(id: "passed", count: breakdown.passed, color: .green)
    return segments
  }

  private struct Segment: Identifiable {
    let id: String
    let startAngle: Angle
    let endAngle: Angle
    let color: Color
  }

  private struct RingSegmentShape: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
      let center = CGPoint(x: rect.midX, y: rect.midY)
      let radius = min(rect.width, rect.height) / 2
      var path = Path()
      path.addArc(
        center: center,
        radius: radius,
        startAngle: startAngle,
        endAngle: endAngle,
        clockwise: false
      )
      return path
    }
  }
}
