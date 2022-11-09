FROM docker.io/archlinux:base-devel

COPY distrobox-check.fish /
COPY dwarves-1.24.tar.xz /tmp
COPY dwarves.patch /tmp
COPY setup-env.sh /
RUN bash /setup-env.sh && fish /distrobox-check.fish && rm /distrobox-check.fish /setup-env.sh

CMD ["/usr/bin/fish", "-l"]
