FROM alpine:edge

MAINTAINER Vishnu Mohan <vishnu@mesosphere.com>

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    ALPINE_EDGE_TESTING_REPO="http://dl-1.alpinelinux.org/alpine/edge/testing/" \
    ALPINE_GLIBC_BASE_URL="https://circle-artifacts.com/gh/andyshinn/alpine-pkg-glibc/6/artifacts/0/home/ubuntu/alpine-pkg-glibc/packages/x86_64" \
    ALPINE_GLIBC_PACKAGE="glibc-2.21-r2.apk" \
    ALPINE_GLIBC_BIN_PACKAGE="glibc-bin-2.21-r2.apk" \
    ANACONDA_VERSION=2.4.0 \
    CONDA_DIR=/opt/conda \
    CONDA_USER=conda \
    CONDA_USER_HOME=/home/conda \
    PATH=/opt/conda/bin:$PATH

# Here we use several hacks collected from https://github.com/gliderlabs/docker-alpine/issues/11
# 1. install GLibc (which is not the cleanest solution at all) 
# 2. hotfix /etc/nsswitch.conf, which is apperently required by glibc and is not used in Alpine Linux
RUN apk --update add \
    bash \
    bzip2 \
    curl \
    ca-certificates \
    git \
    glib \
    jq \
    libstdc++ \
    libsm \
    libxext \
    libxrender \
    openssh-client \
    readline \
    && apk add --update --repository ${ALPINE_EDGE_TESTING_REPO} tini \
    && cd /tmp \
    && wget ${ALPINE_GLIBC_BASE_URL}/${ALPINE_GLIBC_PACKAGE} ${ALPINE_GLIBC_BASE_URL}/${ALPINE_GLIBC_BIN_PACKAGE} \
    && apk add --allow-untrusted ${ALPINE_GLIBC_PACKAGE} ${ALPINE_GLIBC_BIN_PACKAGE} \
    && /usr/glibc/usr/bin/ldconfig /lib /usr/glibc/usr/lib \
    && echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf \
    && wget "https://repo.continuum.io/archive/Anaconda3-${ANACONDA_VERSION}-Linux-x86_64.sh" \
    && bash ./Anaconda3-${ANACONDA_VERSION}-Linux-x86_64.sh -b -p /opt/conda \
    && rm /tmp/* /var/cache/apk/* \
    && echo 'export PATH=/opt/conda/bin:$PATH' >> /etc/profile.d/conda.sh \
    && conda update --all --yes \
    && conda install pip virtualenv anaconda-client --yes \
    && conda clean --tarballs --yes \
    && conda clean --packages --yes

RUN adduser -s /bin/bash -G users -D ${CONDA_USER}
WORKDIR ${CONDA_HOME}
USER conda
RUN conda create -n local_conda --clone=${CONDA_DIR}

COPY anaconda.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/anaconda.sh

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/bin/anaconda.sh"]
