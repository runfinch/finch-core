# syntax = docker/dockerfile:1.4
FROM public.ecr.aws/docker/library/fedora:38

# install necessary cloud-server packages
RUN dnf group install -y cloud-server-environment --exclude=plymouth* \
    --exclude=geolite* \
    --exclude=firewalld* \
    --exclude=grub* \
    --exclude=dracut* \
    --exclude=shim-*

# install packages needed by Lima
RUN dnf install -y \
  --setopt=install_weak_deps=False \
  qemu-user-static-aarch64 \
  qemu-user-static-arm \
  qemu-user-static-x86 \
  iptables \
  fuse-sshfs

RUN systemctl enable cloud-init cloud-init-local cloud-config cloud-final

# enable systemd
# disabled network conf in cloud config
RUN <<EOF cat >> /etc/wsl.conf
[boot]
systemd=true
EOF

RUN <<EOF cat >> /etc/cloud/cloud.cfg
network:
      config: disabled
EOF

# cleanup
RUN dnf clean all &&\
    rm -f /etc/NetworkManager/system-connections/*.nmconnection && \
    truncate -s 0 /etc/machine-id && \
    rm -f /var/lib/systemd/random-seed
