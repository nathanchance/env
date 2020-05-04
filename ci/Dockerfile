FROM archlinux/base:latest
RUN pacman -Syyu --noconfirm
RUN pacman -S --noconfirm bash fd shellcheck shfmt
COPY check.sh /check.sh
ENTRYPOINT ["/check.sh"]
