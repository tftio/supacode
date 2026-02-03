import ComposableArchitecture
import SwiftUI

struct WorktreeSettingsView: View {
  @Bindable var store: StoreOf<SettingsFeature>

  var body: some View {
    VStack(alignment: .leading) {
      Form {
        Section("Worktree") {
          VStack(alignment: .leading) {
            Toggle(
              "Also delete local branch",
              isOn: $store.deleteBranchOnArchive
            )
            .help("Delete the local branch when archiving a worktree")
            Text("Removes the local branch along with the worktree. Remote branches must be deleted on GitHub.")
              .foregroundStyle(.secondary)
            Text("Uncommitted changes will be lost.")
              .foregroundStyle(.red)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          Toggle(
            "Sort merged worktrees to bottom",
            isOn: $store.sortMergedWorktreesToBottom
          )
          .help("Move merged PR worktrees to the bottom of each repository list.")
        }
      }
      .formStyle(.grouped)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}
