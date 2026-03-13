# Rust Development Environment

Complete Rust development setup with toolchain management and code coverage tools.

## Installed Tools

### Core Toolchain

- **rustup** - Rust toolchain manager
  - Manages multiple Rust versions (stable, beta, nightly)
  - Handles cross-compilation targets
  - Manages components (clippy, rustfmt, rust-src, etc.)
  - Provides `cargo` and `rustc` wrappers that use the active toolchain

- **rust-analyzer** - Language Server Protocol (LSP) for IDEs

**Note:** This configuration uses `rustup` to manage Rust toolchains. The `cargo` and `rustc` commands are provided by rustup after you run `rustup default stable`.

### Code Coverage Tools

- **cargo-llvm-cov** - LLVM-based coverage (recommended)
  - Works with stable Rust
  - Accurate line and branch coverage
  - Supports all platforms

- **cargo-tarpaulin** - Coverage with detailed reports
  - HTML and XML output formats
  - Good for CI/CD pipelines
  - Linux-only

## Getting Started

### Initial Setup with rustup

After rebuilding your configuration, initialize rustup:

```bash
# Install the stable toolchain
rustup default stable

# Update all toolchains
rustup update

# Install additional components
rustup component add clippy rustfmt rust-src
```

### Verify Installation

```bash
# Check versions
rustup --version
rustc --version
cargo --version
rust-analyzer --version
cargo llvm-cov --version
cargo tarpaulin --version

# List installed toolchains
rustup show
```

## Usage

### Basic Development

```bash
# Create a new project
cargo new my-project
cd my-project

# Build the project
cargo build

# Run the project
cargo run

# Run tests
cargo test

# Check without building (fast)
cargo check

# Format code
cargo fmt

# Lint code
cargo clippy
```

### Managing Toolchains

```bash
# Install nightly toolchain
rustup toolchain install nightly

# Use nightly for a specific project
rustup override set nightly

# Install a specific version
rustup toolchain install 1.75.0

# List installed toolchains
rustup toolchain list

# Remove a toolchain
rustup toolchain uninstall nightly

# Update all toolchains
rustup update
```

### Cross-Compilation

```bash
# List available targets
rustup target list

# Install a cross-compilation target
rustup target add x86_64-unknown-linux-musl
rustup target add aarch64-unknown-linux-gnu

# Build for a specific target
cargo build --target x86_64-unknown-linux-musl
```

## Code Coverage

### Using cargo-llvm-cov (Recommended)

```bash
# Generate coverage report (terminal)
cargo llvm-cov

# Generate HTML report
cargo llvm-cov --html
# Opens at target/llvm-cov/html/index.html

# Generate lcov format (for CI)
cargo llvm-cov --lcov --output-path lcov.info

# Coverage for specific test
cargo llvm-cov --test integration_test

# Coverage with detailed per-file breakdown
cargo llvm-cov --summary-only

# Run coverage without tests (for doc tests)
cargo llvm-cov --doc
```

**Configuration (.cargo/config.toml):**

```toml
[llvm-cov]
ignore-filename-regex = [
    "tests/",
    "benches/",
]
```

### Using cargo-tarpaulin

```bash
# Generate coverage report (terminal)
cargo tarpaulin

# Generate HTML report
cargo tarpaulin --out Html

# Generate XML for CI (Cobertura format)
cargo tarpaulin --out Xml

# Verbose output
cargo tarpaulin -v

# Ignore test files
cargo tarpaulin --ignore-tests

# Set timeout (default 60s)
cargo tarpaulin --timeout 120
```

**Configuration (tarpaulin.toml):**

```toml
[report]
out = ["Html", "Xml"]

[run]
timeout = "120s"
```

### Comparison: llvm-cov vs tarpaulin

| Feature | cargo-llvm-cov | cargo-tarpaulin |
|---------|----------------|-----------------|
| Platforms | All (Linux, macOS, Windows) | Linux only |
| Accuracy | High (LLVM instrumentation) | High (ptrace-based) |
| Speed | Fast | Slower |
| Setup | Requires LLVM | Works out of box |
| Stability | Very stable | Stable |
| Branch coverage | Yes | Yes |
| **Recommendation** | **Use for most projects** | Use on Linux for CI |

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Coverage

on: [push, pull_request]

jobs:
  coverage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: llvm-tools-preview

      - name: Install cargo-llvm-cov
        run: cargo install cargo-llvm-cov

      - name: Generate coverage
        run: cargo llvm-cov --all-features --workspace --lcov --output-path lcov.info

      - name: Upload to codecov.io
        uses: codecov/codecov-action@v4
        with:
          files: lcov.info
```

### GitLab CI Example

```yaml
coverage:
  image: rust:latest
  before_script:
    - rustup component add llvm-tools-preview
    - cargo install cargo-llvm-cov
  script:
    - cargo llvm-cov --all-features --workspace --lcov --output-path lcov.info
  coverage: '/\d+\.\d+% coverage/'
  artifacts:
    paths:
      - lcov.info
    reports:
      coverage_report:
        coverage_format: cobertura
        path: lcov.info
```

## IDE Integration

### VSCode

Install the "rust-analyzer" extension. It will automatically use the system rust-analyzer.

```json
// settings.json
{
  "rust-analyzer.check.command": "clippy",
  "rust-analyzer.rustfmt.extraArgs": ["+nightly"],
  "rust-analyzer.cargo.features": "all"
}
```

### Neovim

The rust-analyzer LSP is already configured via the neovim mixin.

### Claude Code

Rust tools are automatically available when using Claude Code. The LSP integration provides:
- Code completion
- Go to definition
- Find references
- Inline diagnostics

## Additional Tools (Optional)

To enable more Rust development tools, edit `home-manager/_mixins/languages/rust.nix` and uncomment:

```nix
# cargo-watch       # Auto-rebuild on file changes: cargo watch -x test
# cargo-edit        # cargo add, cargo rm, cargo upgrade
# cargo-outdated    # Check for outdated dependencies
# cargo-audit       # Security vulnerability scanner
# cargo-nextest     # Next-generation test runner
# cargo-expand      # Show macro expansion
# cargo-flamegraph  # Flamegraph profiler
# cargo-udeps       # Find unused dependencies
```

## Troubleshooting

### rustup not found in PATH

Reload your shell or run:

```bash
export PATH="$HOME/.cargo/bin:$PATH"
```

### rust-analyzer not working

```bash
# Restart rust-analyzer
killall rust-analyzer

# Reinstall component
rustup component add rust-analyzer
```

### Coverage not working

```bash
# For cargo-llvm-cov, install LLVM tools
rustup component add llvm-tools-preview

# For cargo-tarpaulin on NixOS, ensure you're on Linux
# It uses ptrace which requires Linux
```

### Multiple Rust versions conflict

```bash
# Check what's active
rustup show

# Use project-specific override
cd my-project
rustup override set stable

# Or use per-command
cargo +nightly build
```

## Best Practices

1. **Use rustup for toolchain management** - Don't mix system Rust with rustup
2. **Pin toolchain version** - Add `rust-toolchain.toml` to your project
3. **Run clippy regularly** - Catch common mistakes early
4. **Use cargo-llvm-cov** - More accurate and works everywhere
5. **Enable CI coverage** - Track coverage over time
6. **Format on save** - Configure your IDE to run `cargo fmt`

## Example Project Setup

```bash
# Create new project
cargo new --bin my-app
cd my-app

# Pin toolchain version
echo 'stable' > rust-toolchain.toml

# Or with more detail:
cat > rust-toolchain.toml <<EOF
[toolchain]
channel = "stable"
components = ["clippy", "rustfmt", "rust-src"]
targets = ["x86_64-unknown-linux-gnu"]
EOF

# Set up coverage configuration
mkdir .cargo
cat > .cargo/config.toml <<EOF
[llvm-cov]
ignore-filename-regex = [
    "tests/",
    "benches/",
]
EOF

# Create .gitignore
cat > .gitignore <<EOF
/target
/lcov.info
/tarpaulin-report.html
Cargo.lock
EOF

# Initialize git
git init
git add .
git commit -m "Initial commit"
```

## See Also

- [Rust Book](https://doc.rust-lang.org/book/)
- [Cargo Book](https://doc.rust-lang.org/cargo/)
- [rustup Documentation](https://rust-lang.github.io/rustup/)
- [cargo-llvm-cov](https://github.com/taiki-e/cargo-llvm-cov)
- [cargo-tarpaulin](https://github.com/xd009642/tarpaulin)
- Configuration: `home-manager/_mixins/languages/rust.nix`
