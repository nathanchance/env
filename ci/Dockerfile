FROM alpine:edge
RUN apk add --no-cache bash fd shellcheck
RUN apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing shfmt
COPY check.sh /check.sh
ENTRYPOINT ["/check.sh"]
