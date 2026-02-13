import Testing

@testable import supacode

struct WorktreeCreationProgressTests {
  @Test func resolvingBaseReferenceUsesHeadFallback() {
    let progress = WorktreeCreationProgress(
      stage: .resolvingBaseReference,
      worktreeName: "swift-otter"
    )

    #expect(progress.titleText == "Creating swift-otter")
    #expect(progress.detailText == "Resolving base reference (HEAD)")
  }

  @Test func creatingWorktreeIncludesBaseRefAndCopyFlags() {
    let progress = WorktreeCreationProgress(
      stage: .creatingWorktree,
      worktreeName: "swift-otter",
      baseRef: "origin/main",
      copyIgnored: true,
      copyUntracked: false
    )

    #expect(progress.titleText == "Creating swift-otter")
    #expect(
      progress.detailText
        == "Creating from origin/main (copy ignored: on, copy untracked: off)"
    )
  }
}
