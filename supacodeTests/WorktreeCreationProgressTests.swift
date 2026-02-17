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
      copyUntracked: false,
      ignoredFilesToCopyCount: 12,
      untrackedFilesToCopyCount: 5
    )

    #expect(progress.titleText == "Creating swift-otter")
    #expect(
      progress.detailText
        == "Creating from main branch. Copying 12 ignored files"
    )
  }

  @Test func creatingWorktreePrefersLatestOutputLineWhenAvailable() {
    let progress = WorktreeCreationProgress(
      stage: .creatingWorktree,
      worktreeName: "swift-otter",
      baseRef: "origin/main",
      copyIgnored: true,
      copyUntracked: true,
      ignoredFilesToCopyCount: 12,
      untrackedFilesToCopyCount: 5,
      latestOutputLine: "[23/100] copy dist/bundle.js"
    )

    #expect(progress.detailText == "[23/100] copy dist/bundle.js")
  }

  @Test func creatingWorktreePrefersLatestBufferedOutputLineWhenAvailable() {
    let progress = WorktreeCreationProgress(
      stage: .creatingWorktree,
      worktreeName: "swift-otter",
      baseRef: "origin/main",
      copyIgnored: true,
      copyUntracked: true,
      ignoredFilesToCopyCount: 12,
      untrackedFilesToCopyCount: 5,
      latestOutputLine: "[23/100] copy dist/bundle.js",
      outputLines: [
        "[22/100] copy src/app.js",
        "[23/100] copy dist/bundle.js",
      ]
    )

    #expect(progress.detailText == "[23/100] copy dist/bundle.js")
    #expect(progress.liveOutputLines == ["[22/100] copy src/app.js", "[23/100] copy dist/bundle.js"])
  }
}
