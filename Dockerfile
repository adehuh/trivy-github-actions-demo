FROM python:3.13-alpine

LABEL org.opencontainers.image.description="Trivy + GitHub Actions demo"

# - apk upgrade: pick up latest OS security fixes
# - remove pip/ensurepip: the app is stdlib-only, and pip's vendored libs
#   (urllib3, msgpack, ...) are the usual source of Trivy HIGH findings
# - create an unprivileged user
RUN apk upgrade --no-cache \
 && rm -rf /usr/local/lib/python3.13/site-packages/pip* \
           /usr/local/lib/python3.13/ensurepip \
           /usr/local/bin/pip* \
 && addgroup -S -g 10001 app \
 && adduser -S -u 10001 -G app app

WORKDIR /srv
COPY app/ ./app/

USER 10001:10001
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1

CMD ["python", "-m", "app.main"]
