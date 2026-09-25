#!/bin/bash
set -e

echo "================================================================"
echo " 🚀 ACMD — macOS Self-Hosted GitHub Actions Runner Installer"
echo "================================================================"

RUNNER_DIR="$HOME/.acmd-runner"
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    RUNNER_ARCH="osx-arm64"
else
    RUNNER_ARCH="osx-x64"
fi

RUNNER_VERSION="2.321.0"
RUNNER_TAR="actions-runner-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"

if [ ! -f "config.sh" ]; then
    echo "⬇️  Downloading GitHub Actions Runner v${RUNNER_VERSION} for ${RUNNER_ARCH}..."
    curl -o "${RUNNER_TAR}" -L "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${RUNNER_TAR}"
    tar xzf "${RUNNER_TAR}"
    rm -f "${RUNNER_TAR}"
fi

echo ""
echo "Please enter your GitHub Repository (e.g. peterfriese/Agentic-Coding-for-Mobile-Developers):"
read -r REPO_NAME

echo "Please enter your GitHub Runner Registration Token (from repo Settings -> Actions -> Runners -> New runner):"
read -r RUNNER_TOKEN

echo "⚙️  Configuring self-hosted runner..."
./config.sh --url "https://github.com/${REPO_NAME}" --token "${RUNNER_TOKEN}" --labels "self-hosted,macOS,ARM64,acmd" --unattended --replace

echo "📦 Installing as macOS background service (launchd)..."
./svc.sh install || true
./svc.sh start || true

echo ""
echo "🎉 Self-Hosted macOS Runner installed and running as a background service!"
echo "Status: Active in ~/.acmd-runner/"
