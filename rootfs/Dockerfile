# syntax = docker/dockerfile:1.4

FROM public.ecr.aws/docker/library/fedora:42 as build

WORKDIR /work

RUN dnf update --best -y

# download and install cosign
ARG COSIGN_VERSION
RUN curl -L -O https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-${COSIGN_VERSION}-1.x86_64.rpm && \
    curl -L -O https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-${COSIGN_VERSION}-1.x86_64.rpm-keyless.pem && \
    curl -L -O https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-${COSIGN_VERSION}-1.x86_64.rpm-keyless.sig && \
    rpm -ivh cosign-${COSIGN_VERSION}-1.x86_64.rpm

# use cosign to verify itself
RUN cosign verify-blob \
    --certificate cosign-${COSIGN_VERSION}-1.x86_64.rpm-keyless.pem \
    --signature cosign-${COSIGN_VERSION}-1.x86_64.rpm-keyless.sig \
    --certificate-identity keyless@projectsigstore.iam.gserviceaccount.com \
    --cert-oidc-issuer https://accounts.google.com \
    cosign-${COSIGN_VERSION}-1.x86_64.rpm

RUN <<EOF cat >> /etc/yum.repos.d/fedora40.repo
[fedora40]
name=Fedora 40
metalink=https://mirrors.fedoraproject.org/metalink?repo=updates-released-f40&arch=\$basearch
enabled=1
countme=1
metadata_expire=7d
repo_gpgcheck=0
type=rpm
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-40
skip_if_unavailable=False
EOF

# Download all qemu-user-static* packages from Fedora 40's update repo
# for installation in the final image
RUN dnf download \
  --repo fedora40 \
  'qemu-user-static*'

FROM public.ecr.aws/docker/library/fedora:42

WORKDIR /work

RUN dnf update --best -y

# install necessary cloud-server packages
RUN dnf group install -y cloud-server-environment --exclude=plymouth* \
    --exclude=geolite* \
    --exclude=firewalld* \
    --exclude=grub* \
    --exclude=dracut* \
    --exclude=shim-* \
    --exclude=audit \
    --exclude=audit-rules

# Remove any existing qemu-user-static packages and then install
# specific version of qemu-user-mode emulators from Fedora 40.
RUN dnf remove -y \
  qemu-user-static \
  qemu-user-static-aarch64 \
  qemu-user-static-arm \
  qemu-user-static-x86

RUN mkdir pkg
COPY --from=build /work/qemu-user-static*.rpm /work/pkg/

# install packages needed by Lima
RUN cd pkg && dnf install -y \
  --setopt=install_weak_deps=False \
  qemu-user-static*.rpm \
  iptables \
  fuse-sshfs \
  btrfs-progs

RUN rm -rf /work/pkg

ARG COSIGN_VERSION
COPY --from=build /work/cosign-${COSIGN_VERSION}-1.x86_64.rpm /work/cosign-${COSIGN_VERSION}-1.x86_64.rpm
  
# install cosign
RUN rpm -ivh cosign-${COSIGN_VERSION}-1.x86_64.rpm && \
    rm -rf cosign-${COSIGN_VERSION}-1.x86_64.rpm

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
