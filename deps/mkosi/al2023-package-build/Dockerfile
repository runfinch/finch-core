FROM public.ecr.aws/amazonlinux/amazonlinux:2023 as builder

WORKDIR /work

ARG FEDORA_VERSION
ENV FEDORA_VERSION=${FEDORA_VERSION:-43}
ENV FEDORA_KEY_NAME="/etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-$FEDORA_VERSION"

COPY "RPM-GPG-KEY-fedora-$FEDORA_VERSION" $FEDORA_KEY_NAME

# install build tools
RUN dnf install -y 'dnf-command(download)' && \
    dnf install -y --allowerasing rpmdevtools rpm-build gnupg2 && \
    rpmdev-setuptree

# add fedora repo
RUN <<EOF cat >> "/etc/yum.repos.d/fedora$FEDORA_VERSION.repo"
[fedora]
name=Fedora $FEDORA_VERSION
metalink=https://mirrors.fedoraproject.org/metalink?repo=fedora-$FEDORA_VERSION&arch=\$basearch
enabled=1
countme=1
metadata_expire=7d
repo_gpgcheck=0
type=rpm
gpgcheck=1
gpgkey=file://$FEDORA_KEY_NAME
skip_if_unavailable=False

[fedora-source]
name=Fedora $FEDORA_VERSION - Source
metalink=https://mirrors.fedoraproject.org/metalink?repo=fedora-source-$FEDORA_VERSION&arch=\$basearch
enabled=1
metadata_expire=7d
repo_gpgcheck=0
type=rpm
gpgcheck=1
gpgkey=file://$FEDORA_KEY_NAME
skip_if_unavailable=False

EOF

# add fedora-updates repo
RUN <<EOF cat >> "/etc/yum.repos.d/fedora-updates$FEDORA_VERSION.repo"
[fedora-updates]
name=Fedora $FEDORA_VERSION updates
metalink=https://mirrors.fedoraproject.org/metalink?repo=updates-released-f$FEDORA_VERSION&arch=\$basearch
enabled=1
countme=1
metadata_expire=7d
repo_gpgcheck=0
type=rpm
gpgcheck=1
gpgkey=file://$FEDORA_KEY_NAME
skip_if_unavailable=False

[fedora-updates-source]
name=Fedora $FEDORA_VERSION - Updates Source
metalink=https://mirrors.fedoraproject.org/metalink?repo=updates-released-source-f$FEDORA_VERSION&arch=\$basearch
enabled=1
repo_gpgcheck=0
type=rpm
gpgcheck=1
metadata_expire=6h
gpgkey=file://$FEDORA_KEY_NAME
skip_if_unavailable=False
EOF

# 1. download the latest fuse-sshfs SRPM from Fedora repos
# 2. disable all Fedora repos
# 3. download cloud-init SRPM from default (AL2023) repos
RUN dnf download \
    --repo fedora \
    --repo fedora-source \
    --repo fedora-updates \
    --repo fedora-updates-source \
    --source fuse-sshfs && \
    dnf config-manager --set-disabled fedora* && \
    dnf download --source cloud-init

COPY patches /work/patches

# build fuse-sshfs
RUN rpm -ivh fuse-sshfs*.src.rpm && \
    dnf builddep -y /root/rpmbuild/SPECS/fuse-sshfs*.spec && \
    rpmbuild --rebuild fuse-sshfs*.src.rpm

# build cloud-init
RUN rpm -ivh cloud-init*.src.rpm && \
    patch -p1 /root/rpmbuild/SPECS/cloud-init.spec patches/cloud-init/0001-disable-mounts-module-patch.patch && \
    dnf builddep -y /root/rpmbuild/SPECS/cloud-init.spec && \
    rpmbuild -ba /root/rpmbuild/SPECS/cloud-init.spec

FROM scratch

COPY --from=builder /root/rpmbuild/RPMS/*/* /
