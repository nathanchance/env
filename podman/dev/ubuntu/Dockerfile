FROM docker.io/ubuntu:rolling

COPY distrobox-check.fish /
COPY setup-env.sh /
ARG GITHUB_TOKEN
RUN bash /setup-env.sh && fish /distrobox-check.fish && rm /distrobox-check.fish /setup-env.sh

CMD ["/usr/bin/fish", "-l"]
