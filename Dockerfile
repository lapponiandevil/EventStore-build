FROM centos:latest
MAINTAINER Henrik Feldt <henrik@haf.se>

# mono & es build deps
RUN yum update -y && yum install -y epel-release yum-utils && \
    rpm --rebuilddb && \
    rpm --import "http://keyserver.ubuntu.com/pks/lookup?op=get&search=0x3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF" && \
    yum-config-manager --add-repo http://download.mono-project.com/repo/centos/ && \

    yum install -y \
    make tar patch gcc gcc-c++ git subversion \
    libgdiplus \
    glib2-devel \
    libpng-devel \
    libjpeg-turbo-devel \
    giflib-devel \
    libtiff-devel \
    libexif-devel \
    libX11-devel \
    fontconfig-devel \
    gettext \
    autoconf \
    automake \
    libtool

RUN  yum install -y mono-complete

ENV PKG_CONFIG_PATH /usr/lib64/pkgconfig
RUN pkg-config --cflags monosgen-2 # sanity check after installation
RUN echo "PKG_CONFIG_PATH: $PKG_CONFIG_PATH, PATH: $PATH, Mono Version: $(mono --version)"

# build es
ENV ITERATION 1
ENV ES_VERSION 3.2.0

RUN git clone https://github.com/EventStore/EventStore.git /tmp/esrepo
WORKDIR /tmp/esrepo
RUN git checkout release-v3.2.0
RUN git submodule update --init
RUN ./build.sh full $ES_VERSION x64 release
RUN ./scripts/package-mono/package-mono-ubuntu.sh $ES_VERSION

# package es
RUN rpm --rebuilddb && \
    yum install -y ruby-devel rubygems rubygems-devel rpm-build redhat-rpm-config && \
    gem install fpm --no-rdoc --no-ri
RUN mkdir -p /tmp/pkgbase/opt/eventstore
WORKDIR /tmp/pkgbase
RUN tar xf /tmp/esrepo/packages/EventStore-OSS-Mono-Ubuntu-v$ES_VERSION.tar.gz && \
    mv EventStore-OSS-Mono-Ubuntu-v$ES_VERSION/* ./opt/eventstore && \
    rmdir EventStore-OSS-Mono-Ubuntu-v$ES_VERSION/ && \
    fpm -s dir -t rpm -n eventstore -v $ES_VERSION --iteration $ITERATION -a x86_64 -C /tmp/pkgbase .

VOLUME ["/tmp/home"]
WORKDIR /tmp/home
ENTRYPOINT ["/bin/bash"]
