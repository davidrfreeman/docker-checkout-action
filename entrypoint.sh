#!/usr/bin/env bash
set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Debug: Show all relevant environment variables
log_info "Environment variables:"
echo "  GITHUB_REPOSITORY=${GITHUB_REPOSITORY:-not set}"
echo "  GITHUB_SERVER_URL=${GITHUB_SERVER_URL:-not set}"
echo "  GITHUB_REF_NAME=${GITHUB_REF_NAME:-not set}"
echo "  GITHUB_SHA=${GITHUB_SHA:-not set}"
echo "  GITHUB_WORKSPACE=${GITHUB_WORKSPACE:-not set}"
echo "  INPUT_REPOSITORY=${INPUT_REPOSITORY:-not set}"
echo "  INPUT_REF=${INPUT_REF:-not set}"
echo "  INPUT_TOKEN=${INPUT_TOKEN:+***set***}"

# Get inputs with defaults
REPOSITORY="${INPUT_REPOSITORY:-${GITHUB_REPOSITORY}}"
REF="${INPUT_REF:-${GITHUB_REF_NAME:-main}}"
TOKEN="${INPUT_TOKEN:-}"
SSH_KEY="${INPUT_SSH_KEY:-}"
SSH_KNOWN_HOSTS="${INPUT_SSH_KNOWN_HOSTS:-}"
PERSIST_CREDENTIALS="${INPUT_PERSIST_CREDENTIALS:-true}"
CHECKOUT_PATH="${INPUT_PATH:-.}"
CLEAN="${INPUT_CLEAN:-true}"
FETCH_DEPTH="${INPUT_FETCH_DEPTH:-1}"
LFS="${INPUT_LFS:-false}"
SUBMODULES="${INPUT_SUBMODULES:-false}"
SET_SAFE_DIRECTORY="${INPUT_SET_SAFE_DIRECTORY:-true}"

# Validate required variables
if [ -z "${REPOSITORY}" ] || [[ "${REPOSITORY}" == *'${'* ]]; then
    log_error "REPOSITORY is not set correctly"
    log_error "REPOSITORY value: '${REPOSITORY}'"
    log_error ""
    log_error "This usually means:"
    log_error "  1. The action is not receiving environment variables from the runner"
    log_error "  2. You need to explicitly set the repository input:"
    log_error ""
    log_error "     - uses: docker-checkout-action@v1"
    log_error "       with:"
    log_error "         repository: owner/repo-name"
    exit 1
fi

if [ -z "${GITHUB_SERVER_URL}" ] || [[ "${GITHUB_SERVER_URL}" == *'${'* ]]; then
    log_warn "GITHUB_SERVER_URL not set, defaulting to https://github.com"
    GITHUB_SERVER_URL="https://github.com"
fi

# Determine workspace
WORKSPACE="${GITHUB_WORKSPACE:-.}"
FULL_PATH="${WORKSPACE}/${CHECKOUT_PATH}"

log_info "Starting checkout process..."
log_info "Repository: ${REPOSITORY}"
log_info "Reference: ${REF}"
log_info "Path: ${FULL_PATH}"
log_info "Fetch depth: ${FETCH_DEPTH}"
log_info "Server URL: ${GITHUB_SERVER_URL}"

# Create directory if it doesn't exist
mkdir -p "${FULL_PATH}"
cd "${FULL_PATH}"

# Set safe directory
if [ "${SET_SAFE_DIRECTORY}" = "true" ]; then
    log_info "Setting ${FULL_PATH} as safe directory..."
    git config --global --add safe.directory "${FULL_PATH}"
fi

# Setup SSH if key provided
if [ -n "${SSH_KEY:-}" ]; then
    log_info "Configuring SSH key..."
    mkdir -p ~/.ssh
    echo "${SSH_KEY}" > ~/.ssh/id_rsa
    chmod 600 ~/.ssh/id_rsa

    if [ -n "${SSH_KNOWN_HOSTS:-}" ]; then
        echo "${SSH_KNOWN_HOSTS}" > ~/.ssh/known_hosts
    else
        # Add common git hosting services
        ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null || true
        ssh-keyscan gitlab.com >> ~/.ssh/known_hosts 2>/dev/null || true

        # For self-hosted Forgejo/Gitea, extract and scan the host
        if [ -n "${GITHUB_SERVER_URL:-}" ]; then
            SERVER_HOST=$(echo "${GITHUB_SERVER_URL}" | sed 's|https://||' | sed 's|http://||' | cut -d'/' -f1)
            if [[ ! "${SERVER_HOST}" =~ github\.com|gitlab\.com ]]; then
                log_info "Adding SSH key for self-hosted Git server: ${SERVER_HOST}"
                ssh-keyscan -p 22 "${SERVER_HOST}" >> ~/.ssh/known_hosts 2>/dev/null || true
            fi
        fi
    fi

    # Use SSH URL
    if [[ "${GITHUB_SERVER_URL:-}" == *"github.com"* ]]; then
        REPO_URL="git@github.com:${REPOSITORY}.git"
    else
        # For Forgejo/Gitea instances, construct SSH URL
        SERVER_HOST=$(echo "${GITHUB_SERVER_URL}" | sed 's|https://||' | sed 's|http://||' | cut -d'/' -f1)
        REPO_URL="git@${SERVER_HOST}:${REPOSITORY}.git"
    fi
else
    # Use HTTPS with token if available
    if [ -n "${TOKEN:-}" ] && [ "${TOKEN}" != "null" ] && [ "${TOKEN}" != "" ]; then
        # Extract server from GITHUB_SERVER_URL
        SERVER="${GITHUB_SERVER_URL:-https://github.com}"

        # Remove trailing slashes
        SERVER="${SERVER%/}"

        # Insert token into URL
        if [[ "${SERVER}" == https://* ]]; then
            # For https URLs, insert token after https://
            REPO_URL="${SERVER/https:\/\//https:\/\/${TOKEN}@}/${REPOSITORY}.git"
        elif [[ "${SERVER}" == http://* ]]; then
            # For http URLs (self-hosted without SSL), insert token after http://
            REPO_URL="${SERVER/http:\/\//http:\/\/${TOKEN}@}/${REPOSITORY}.git"
        else
            # Fallback: assume https
            REPO_URL="https://${TOKEN}@${SERVER}/${REPOSITORY}.git"
        fi
        log_info "Using HTTPS with authentication token"
    else
        # Public repo, no auth
        SERVER="${GITHUB_SERVER_URL:-https://github.com}"
        SERVER="${SERVER%/}"
        REPO_URL="${SERVER}/${REPOSITORY}.git"
        log_info "Using HTTPS without authentication (public repository)"
    fi
fi

log_info "Repository URL: ${REPO_URL//:[^:]*@/:***@}" # Mask token in logs

# Check if directory is already a git repo
if [ -d ".git" ]; then
    log_info "Existing repository detected"

    if [ "${CLEAN}" = "true" ]; then
        log_info "Cleaning working directory..."
        git clean -ffdx
        git reset --hard HEAD
    fi

    # Update remote URL
    git remote set-url origin "${REPO_URL}" 2>/dev/null || git remote add origin "${REPO_URL}"

    # Fetch
    log_info "Fetching updates..."
    if [ "${FETCH_DEPTH}" = "0" ]; then
        git fetch origin
    else
        git fetch --depth="${FETCH_DEPTH}" origin
    fi

    # Checkout
    if [ -n "${REF}" ]; then
        log_info "Checking out ${REF}..."
        git checkout "${REF}" 2>/dev/null || git checkout -b "${REF}" "origin/${REF}"
    elif [ -n "${GITHUB_SHA}" ]; then
        log_info "Checking out commit ${GITHUB_SHA}..."
        git checkout "${GITHUB_SHA}"
    fi
else
    # Fresh clone
    log_info "Cloning repository..."

    CLONE_ARGS=()

    if [ "${FETCH_DEPTH}" != "0" ]; then
        CLONE_ARGS+=("--depth=${FETCH_DEPTH}")
    fi

    if [ -n "${REF}" ]; then
        CLONE_ARGS+=("--branch=${REF}")
    fi

    # Clone into temporary directory first, then move contents
    TMP_DIR=$(mktemp -d)
    git clone "${CLONE_ARGS[@]}" "${REPO_URL}" "${TMP_DIR}"

    # Move contents to target directory
    shopt -s dotglob
    mv "${TMP_DIR}"/* "${FULL_PATH}/" 2>/dev/null || true
    rmdir "${TMP_DIR}"

    cd "${FULL_PATH}"

    # If specific SHA is needed and different from current HEAD
    if [ -n "${GITHUB_SHA}" ] && [ "$(git rev-parse HEAD)" != "${GITHUB_SHA}" ]; then
        log_info "Fetching specific commit ${GITHUB_SHA}..."
        git fetch --depth=1 origin "${GITHUB_SHA}"
        git checkout "${GITHUB_SHA}"
    fi
fi

# Handle submodules
if [ "${SUBMODULES}" = "true" ] || [ "${SUBMODULES}" = "recursive" ]; then
    log_info "Initializing submodules..."
    if [ "${SUBMODULES}" = "recursive" ]; then
        git submodule update --init --recursive
    else
        git submodule update --init
    fi
fi

# Handle Git LFS
if [ "${LFS}" = "true" ]; then
    log_info "Pulling Git LFS files..."
    git lfs install
    git lfs pull
fi

# Persist credentials if requested
if [ "${PERSIST_CREDENTIALS}" = "true" ]; then
    if [ -n "${TOKEN:-}" ] && [ "${TOKEN}" != "null" ] && [ "${TOKEN}" != "" ]; then
        log_info "Persisting credentials in git config..."

        # Store credentials for the repository
        SERVER="${GITHUB_SERVER_URL:-https://github.com}"
        SERVER="${SERVER%/}"

        # Extract protocol and host
        if [[ "${SERVER}" == https://* ]]; then
            PROTOCOL="https"
            HOST="${SERVER#https://}"
        elif [[ "${SERVER}" == http://* ]]; then
            PROTOCOL="http"
            HOST="${SERVER#http://}"
        else
            PROTOCOL="https"
            HOST="${SERVER}"
        fi

        # Create credential entry
        mkdir -p ~/.config/git
        echo "${PROTOCOL}://${TOKEN}@${HOST}" >> ~/.config/git/credentials
        chmod 600 ~/.config/git/credentials

        # Configure git credential helper
        git config --global credential.helper "store --file=$HOME/.config/git/credentials"
    fi
else
    # Remove credentials from URL if not persisting
    if [ -n "${TOKEN:-}" ] && [ "${TOKEN}" != "null" ] && [ "${TOKEN}" != "" ]; then
        SERVER="${GITHUB_SERVER_URL:-https://github.com}"
        SERVER="${SERVER%/}"
        CLEAN_URL="${SERVER}/${REPOSITORY}.git"
        git remote set-url origin "${CLEAN_URL}"
    fi
fi

# Display final status
log_info "Checkout complete!"
log_info "Current commit: $(git rev-parse HEAD)"
log_info "Current branch: $(git rev-parse --abbrev-ref HEAD)"

# Output information for subsequent steps
echo "commit-sha=$(git rev-parse HEAD)" >> "${GITHUB_OUTPUT:-/dev/null}"
echo "branch=$(git rev-parse --abbrev-ref HEAD)" >> "${GITHUB_OUTPUT:-/dev/null}"
