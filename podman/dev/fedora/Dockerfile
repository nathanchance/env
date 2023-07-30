FROM docker.io/fedora:38

COPY distrobox-check.fish /
COPY setup-env.sh /
RUN bash /setup-env.sh && fish /distrobox-check.fish && rm /distrobox-check.fish /setup-env.sh

CMD ["/usr/bin/fish", "-l"]
