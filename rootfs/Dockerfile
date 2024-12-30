# syntax = docker/dockerfile:1.4

FROM public.ecr.aws/docker/library/fedora:40 as build

WORKDIR /work

RUN dnf update --best -y

# download and install cosign
RUN curl -L -O https://github.com/sigstore/cosign/releases/download/v2.2.4/cosign-2.2.4-1.x86_64.rpm && \
    curl -L -O https://github.com/sigstore/cosign/releases/download/v2.2.4/cosign-2.2.4-1.x86_64.rpm-keyless.pem && \
    curl -L -O https://github.com/sigstore/cosign/releases/download/v2.2.4/cosign-2.2.4-1.x86_64.rpm-keyless.sig && \
    rpm -ivh cosign-2.2.4-1.x86_64.rpm

# use cosign to verify itself
RUN cosign verify-blob \
    --certificate cosign-2.2.4-1.x86_64.rpm-keyless.pem \
    --signature cosign-2.2.4-1.x86_64.rpm-keyless.sig \
    --certificate-identity keyless@projectsigstore.iam.gserviceaccount.com \
    --cert-oidc-issuer https://accounts.google.com \
    cosign-2.2.4-1.x86_64.rpm

FROM public.ecr.aws/docker/library/fedora:40

WORKDIR /work

RUN dnf update --best -y

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
  fuse-sshfs \
  btrfs-progs

COPY --from=build /work/cosign-2.2.4-1.x86_64.rpm /work/cosign-2.2.4-1.x86_64.rpm
  
# install cosign
RUN rpm -ivh cosign-2.2.4-1.x86_64.rpm && \
    rm -rf cosign-2.2.4-1.x86_64.rpm

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
RUN dnf clean all && \
    rm -f /etc/NetworkManager/system-connections/*.nmconnection && \
    truncate -s 0 /etc/machine-id && \
    rm -f /var/lib/systemd/random-seed
