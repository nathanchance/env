FROM alpine:edge
RUN apk add --no-cache bash fd shellcheck shfmt
COPY check.sh /check.sh
ENTRYPOINT ["/check.sh"]
