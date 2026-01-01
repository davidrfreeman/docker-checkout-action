FROM alpine:3.19

# Install git, openssh, and git-lfs
RUN apk add --no-cache \
    git \
    git-lfs \
    openssh-client \
    bash \
    curl \
    ca-certificates

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
