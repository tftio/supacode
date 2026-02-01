# Supacode

A macOS app for running multiple coding agents in parallel, powered by [GhosttyKit](https://github.com/ghostty-org/ghostty).

## Requirements

- macOS 26.0+
- [mise](https://mise.jdx.dev/) (for building GhosttyKit)

## Building

```bash
make build-ghostty-xcframework  # Build GhosttyKit from Zig source
make build-app                   # Build macOS app (Debug)
make run-app                     # Build and launch
```

## Development

```bash
make check     # Run swiftformat and swiftlint
make test      # Run tests
make format    # Run swift-format
```

## License

Proprietary
