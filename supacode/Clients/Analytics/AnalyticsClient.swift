import ComposableArchitecture
import PostHog

struct AnalyticsClient {
  var capture: @Sendable (_ event: String, _ properties: [String: Any]?) -> Void
}

extension AnalyticsClient: DependencyKey {
  static let liveValue = AnalyticsClient(
    capture: { event, properties in
      #if !DEBUG
        PostHogSDK.shared.capture(event, properties: properties)
      #endif
    }
  )

  static let testValue = AnalyticsClient(
    capture: { _, _ in }
  )
}

extension DependencyValues {
  var analyticsClient: AnalyticsClient {
    get { self[AnalyticsClient.self] }
    set { self[AnalyticsClient.self] = newValue }
  }
}
