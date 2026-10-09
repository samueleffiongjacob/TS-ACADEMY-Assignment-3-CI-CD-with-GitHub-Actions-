# Small Linux base image
FROM alpine:3.20

# Only bash is required (busybox provides the rest). --no-cache keeps the image small.
RUN apk add --no-cache bash

# Run as an unprivileged user
RUN addgroup -S app && adduser -S -G app app

WORKDIR /app
COPY app/ /app/
RUN chmod +x /app/*.sh

USER app

# `docker run devops-tool <command>` passes <command> to app.sh.
ENTRYPOINT ["/app/app.sh"]
CMD ["help"]
