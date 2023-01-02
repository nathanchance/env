ARG BASE
FROM ${BASE}

COPY setup-env.sh /
COPY dwarves-1.24.tar.xz /tmp
COPY ea30d58a2329764b9515bbe671575260c76f8114.patch /tmp
COPY distrobox-check.fish /

ARG BASE
ARG COMPILER
ARG GITHUB_TOKEN
RUN bash /setup-env.sh ${BASE} ${COMPILER} && fish /distrobox-check.fish && rm -f /distrobox-check.fish /setup-env.sh

CMD ["/usr/bin/fish", "-l"]
