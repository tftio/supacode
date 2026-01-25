import SwiftUI

struct TerminalTabView: View {
  let tab: TerminalTabItem
  let isActive: Bool
  let isDragging: Bool
  let tabIndex: Int
  let fixedWidth: CGFloat?
  let onSelect: () -> Void
  let onClose: () -> Void
  @Binding var closeButtonGestureActive: Bool

  @State private var isHovering = false
  @State private var isHoveringClose = false
  @State private var isPressing = false

  var body: some View {
    Button(action: onSelect) {
      TerminalTabLabelView(
        tab: tab,
        isActive: isActive,
        isHoveringTab: isHovering,
        isDragging: isDragging,
        tabIndex: tabIndex,
        closeAction: onClose,
        closeButtonGestureActive: $closeButtonGestureActive,
        isHoveringClose: $isHoveringClose
      )
    }
    .buttonStyle(TerminalTabButtonStyle(isPressing: $isPressing))
    .background {
      TerminalTabBackground(
        isActive: isActive,
        isPressing: isPressing,
        isDragging: isDragging,
        isHovering: isHovering
      )
        .animation(.easeInOut(duration: TerminalTabBarMetrics.hoverAnimationDuration), value: isHovering)
    }
    .frame(
      minWidth: TerminalTabBarMetrics.tabMinWidth,
      maxWidth: TerminalTabBarMetrics.tabMaxWidth,
      minHeight: TerminalTabBarMetrics.tabHeight,
      maxHeight: TerminalTabBarMetrics.tabHeight
    )
    .frame(width: fixedWidth)
    .padding(.bottom, isActive ? TerminalTabBarMetrics.activeTabBottomPadding : 0)
    .offset(y: isActive ? TerminalTabBarMetrics.activeTabOffset : 0)
    .clipShape(.rect(cornerRadius: TerminalTabBarMetrics.tabCornerRadius))
    .contentShape(.rect)
    .onHover { hovering in
      isHovering = hovering
    }
    .zIndex(isActive ? 2 : (isDragging ? 3 : 0))
    .help("Open tab \(tab.title) (no shortcut)")
    .accessibilityLabel(tab.title)
  }
}
