# Webhook listener that runs deploy.sh against the host Docker daemon.
FROM docker:28-cli

RUN apk add --no-cache bash curl flock git openssh-client webhook \
    && git config --system --add safe.directory '*'

ENTRYPOINT ["webhook"]
