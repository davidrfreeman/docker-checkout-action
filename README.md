# Docker Checkout Action

A Docker-based Git checkout action that **doesn't require Node.js**. Perfect for use with Forgejo, Gitea, or GitHub Actions when you want to use minimal container images.

## Why This Action?

The standard `actions/checkout` action is written in JavaScript and requires Node.js to be installed in your job container. This action uses Docker instead, allowing you to use any base image (Python, Go, Rust, Alpine, etc.) without needing Node.js.

**This action uses pre-built Docker images** hosted on GitHub Container Registry (ghcr.io) for fast execution - no build time required!

## Features

✅ **No Node.js required** - Works with any container image
✅ **Pre-built images** - Fast execution, no build time
✅ **Multi-platform** - Supports AMD64 and ARM64
✅ **Full Git functionality** - Supports branches, tags, commits, and SHA checkouts
✅ **Submodules support** - Can recursively checkout submodules
✅ **Git LFS support** - Download large files if needed
✅ **SSH & HTTPS** - Supports both authentication methods
✅ **Forgejo/Gitea compatible** - Works seamlessly with self-hosted Git servers
✅ **GitHub compatible** - Drop-in replacement for basic `actions/checkout` usage

## Usage

### Basic Usage

```yaml
name: CI
on: [push]

jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: python:3.11-slim  # No Node.js needed!
    steps:
      - uses: YOUR_GITHUB_USERNAME/docker-checkout-action@v1

      - name: Run tests
        run: |
          pip install pytest
          pytest
```

### With Forgejo/Gitea (Self-Hosted)

**Important:** With Forgejo, you may need to explicitly specify the repository:

```yaml
name: Build
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: golang:1.21-alpine
    steps:
      # Explicit repository specification (recommended for Forgejo)
      - uses: https://github.com/davidrfreeman/docker-checkout-action@v0.1.7
        with:
          repository: ${{ github.repository }}

      - name: Build
        run: go build -v ./...
```

### With Forgejo/Gitea (Private Repository)

```yaml
steps:
  # Private repository - use Forgejo's token
  - uses: https://github.com/davidrfreeman/docker-checkout-action@v0.1.7
    with:
      repository: ${{ github.repository }}
      token: ${{ secrets.GITHUB_TOKEN }}
```

**Note:** Forgejo provides these context variables:
- `${{ github.repository }}` - Current repository (e.g., `owner/repo`)
- `${{ github.server_url }}` - Your Forgejo instance URL
- `${{ secrets.GITHUB_TOKEN }}` - Automatic token for the current repository

### Advanced Usage

```yaml
steps:
  # Checkout specific branch
  - uses: YOUR_GITHUB_USERNAME/docker-checkout-action@v1
    with:
      ref: develop

  # Checkout with submodules
  - uses: YOUR_GITHUB_USERNAME/docker-checkout-action@v1
    with:
      submodules: recursive

  # Full history (all commits)
  - uses: YOUR_GITHUB_USERNAME/docker-checkout-action@v1
    with:
      fetch-depth: 0

  # With Git LFS
  - uses: YOUR_GITHUB_USERNAME/docker-checkout-action@v1
    with:
      lfs: true

  # Checkout to specific path
  - uses: YOUR_GITHUB_USERNAME/docker-checkout-action@v1
    with:
      path: my-repo
```

## Inputs

| Input                 | Description                                              | Default                    |
|-----------------------|----------------------------------------------------------|----------------------------|
| `repository`          | Repository name with owner (e.g., `octocat/hello-world`) | `${{ github.repository }}` |
| `ref`                 | Branch, tag, or SHA to checkout                          | Event ref/SHA              |
| `token`               | Personal access token for private repos                  | `${{ github.token }}`      |
| `ssh-key`             | SSH private key for authentication                       | `''`                       |
| `ssh-known-hosts`     | Known hosts for SSH                                      | `''`                       |
| `persist-credentials` | Keep credentials in git config                           | `true`                     |
| `path`                | Relative path to checkout repo                           | `.`                        |
| `clean`               | Clean working directory before checkout                  | `true`                     |
| `fetch-depth`         | Number of commits to fetch (0 = all)                     | `1`                        |
| `lfs`                 | Whether to download Git LFS files                        | `false`                    |
| `submodules`          | Checkout submodules (`true`/`recursive`/`false`)         | `false`                    |
| `set-safe-directory`  | Mark directory as safe                                   | `true`                     |

## Outputs

| Output       | Description                         |
|--------------|-------------------------------------|
| `commit-sha` | The commit SHA that was checked out |
| `branch`     | The branch that was checked out     |

## Examples

### Python Project

```yaml
name: Python Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: python:3.11-slim
    steps:
      - uses: YOUR_GITHUB_USERNAME/docker-checkout-action@v1

      - name: Install dependencies
        run: |
          pip install --upgrade pip
          pip install -r requirements.txt

      - name: Run tests
        run: pytest
```

### Rust Project

```yaml
name: Rust Build
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: rust:1.75-alpine
    steps:
      - uses: YOUR_GITHUB_USERNAME/docker-checkout-action@v1

      - name: Build
        run: cargo build --release
```

### Multi-Platform

```yaml
name: Multi-Platform
on: [push]

jobs:
  test:
    strategy:
      matrix:
        image: [python:3.11-slim, python:3.12-slim, python:3.10-slim]
    runs-on: ubuntu-latest
    container:
      image: ${{ matrix.image }}
    steps:
      - uses: YOUR_GITHUB_USERNAME/docker-checkout-action@v1
      - run: python --version
      - run: pip install pytest && pytest
```

### With Submodules and LFS

```yaml
name: Full Checkout
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: alpine:latest
    steps:
      - uses: YOUR_GITHUB_USERNAME/docker-checkout-action@v1
        with:
          submodules: recursive
          lfs: true
          fetch-depth: 0

      - name: Show repository contents
        run: |
          apk add tree
          tree -L 2
```

## Comparison with actions/checkout

| Feature                   | actions/checkout | docker-checkout-action   |
|---------------------------|------------------|--------------------------|
| Requires Node.js          | ✅ Yes            | ❌ No                     |
| Works with minimal images | ❌ No             | ✅ Yes                    |
| Forgejo/Gitea support     | ✅ Yes            | ✅ Yes                    |
| Submodules                | ✅ Yes            | ✅ Yes                    |
| Git LFS                   | ✅ Yes            | ✅ Yes                    |
| Speed                     | Faster (native)  | Slightly slower (Docker) |
| Advanced features         | More             | Basic                    |

## Troubleshooting

### Permission Denied

If you get permission errors, ensure your runner has Docker socket access:

```yaml
services:
  runner:
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

### Private Repositories

For private repositories, pass a token:

```yaml
- uses: YOUR_GITHUB_USERNAME/docker-checkout-action@v1
  with:
    token: ${{ secrets.GITHUB_TOKEN }}
```

For Forgejo, generate a token in your user settings and add it as a secret.

### SSH Authentication

```yaml
- uses: YOUR_GITHUB_USERNAME/docker-checkout-action@v1
  with:
    ssh-key: ${{ secrets.SSH_PRIVATE_KEY }}
    ssh-known-hosts: ${{ secrets.SSH_KNOWN_HOSTS }}
```

## License

MIT License - see LICENSE file for details.

## Acknowledgments

Inspired by the need for Node.js-free checkouts in minimal container images. Built for the Forgejo/Gitea community.
