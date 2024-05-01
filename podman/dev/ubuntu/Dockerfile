# Switch back to rolling when https://github.com/llvm/llvm-project/issues/90536 is fixed
FROM docker.io/ubuntu:22.04

COPY distrobox-check.fish /
COPY setup-env.sh /
ARG GITHUB_TOKEN
RUN bash /setup-env.sh && fish /distrobox-check.fish && rm /distrobox-check.fish /setup-env.sh

CMD ["/usr/bin/fish", "-l"]
