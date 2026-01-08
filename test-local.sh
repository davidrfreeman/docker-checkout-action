#!/bin/bash
# Local testing script for the checkout action

set -e

echo "=== Building Docker Image ==="
docker build -t test-checkout-action .

echo ""
echo "=== Test 1: GitHub Public Repository ==="
docker run --rm \
  -e INPUT_REPOSITORY="torvalds/linux" \
  -e INPUT_FETCH_DEPTH="1" \
  -e GITHUB_SERVER_URL="https://github.com" \
  -e GITHUB_REPOSITORY="torvalds/linux" \
  -e GITHUB_REF_NAME="master" \
  -e GITHUB_WORKSPACE="/workspace" \
  -v "$(pwd)/test-workspace:/workspace" \
  test-checkout-action

echo ""
echo "=== Test 2: GitHub with Shallow Clone ==="
rm -rf test-workspace/*
docker run --rm \
  -e INPUT_REPOSITORY="davidrfreeman/docker-checkout-action" \
  -e INPUT_FETCH_DEPTH="1" \
  -e GITHUB_SERVER_URL="https://github.com" \
  -e GITHUB_REPOSITORY="davidrfreeman/docker-checkout-action" \
  -e GITHUB_REF_NAME="main" \
  -e GITHUB_WORKSPACE="/workspace" \
  -v "$(pwd)/test-workspace:/workspace" \
  test-checkout-action

echo ""
echo "=== Test 3: Forgejo/Gitea Instance (Simulated) ==="
rm -rf test-workspace/*
# Replace with your actual Forgejo instance URL and repo
FORGEJO_URL="${FORGEJO_URL:-https://forgejo.echo-logarithm.ts.net}"
FORGEJO_REPO="${FORGEJO_REPO:-vuln-dashboard/workflows}"
FORGEJO_TOKEN="${FORGEJO_TOKEN:-}"

if [ -n "${FORGEJO_TOKEN}" ]; then
  echo "Testing with Forgejo instance: ${FORGEJO_URL}"
  docker run --rm \
    -e INPUT_REPOSITORY="${FORGEJO_REPO}" \
    -e INPUT_TOKEN="${FORGEJO_TOKEN}" \
    -e INPUT_FETCH_DEPTH="1" \
    -e GITHUB_SERVER_URL="${FORGEJO_URL}" \
    -e GITHUB_REPOSITORY="${FORGEJO_REPO}" \
    -e GITHUB_REF_NAME="main" \
    -e GITHUB_WORKSPACE="/workspace" \
    -v "$(pwd)/test-workspace:/workspace" \
    test-checkout-action
else
  echo "Skipping Forgejo test (set FORGEJO_URL, FORGEJO_REPO, FORGEJO_TOKEN to test)"
fi

echo ""
echo "=== Test 4: Custom Path ==="
rm -rf test-workspace/*
docker run --rm \
  -e INPUT_REPOSITORY="davidrfreeman/docker-checkout-action" \
  -e INPUT_PATH="custom-dir" \
  -e INPUT_FETCH_DEPTH="1" \
  -e GITHUB_SERVER_URL="https://github.com" \
  -e GITHUB_REPOSITORY="davidrfreeman/docker-checkout-action" \
  -e GITHUB_REF_NAME="main" \
  -e GITHUB_WORKSPACE="/workspace" \
  -v "$(pwd)/test-workspace:/workspace" \
  test-checkout-action

if [ -d "test-workspace/custom-dir/.git" ]; then
  echo "✓ Custom path test PASSED"
else
  echo "✗ Custom path test FAILED"
  exit 1
fi

echo ""
echo "=== All Tests Passed! ==="
echo ""
echo "Workspace contents:"
ls -la test-workspace/

# Cleanup
rm -rf test-workspace
