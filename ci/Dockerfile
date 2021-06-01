FROM alpine:edge
RUN apk add --no-cache bash fd fish shellcheck shfmt
COPY check.sh /check.sh
ENTRYPOINT ["/check.sh"]
