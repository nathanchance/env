FROM docker.io/alpine:edge

COPY distrobox-check.fish /
COPY dwarves-1.25.tar.xz /tmp
COPY packages/ /tmp/packages/
COPY setup-env.sh /
RUN sh /setup-env.sh && fish /distrobox-check.fish && rm /distrobox-check.fish /setup-env.sh

CMD ["/usr/bin/fish", "-l"]
