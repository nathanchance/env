FROM registry.fedoraproject.org/fedora:rawhide

COPY distrobox-check.fish /
COPY setup-env.sh /
RUN bash /setup-env.sh && fish /distrobox-check.fish && rm /distrobox-check.fish /setup-env.sh

CMD ["/usr/bin/fish", "-l"]
