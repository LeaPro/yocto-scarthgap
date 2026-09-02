# this Dockerfile creates an image that works on linux mint 22.1 (ubuntu 24.04 based)
#
# docker build --tag "lea-yocto-scarthgap" --build-arg "USER=$(whoami)" --build-arg "host_uid=$(id -u)" --build-arg "host_gid=$(id -g)" .
#
# run with a variation of the following command (note mac-address for ADI CCES license and yocto downloads/sstate-cache symlink mapping)
# docker run --rm --mac-address="a4:4c:c8:29:84:c4" -it -v $HOME:$HOME -v /media/wap/HDD/yocto-scarthgap-shared/downloads:/media/wap/HDD/yocto-scarthgap-shared/downloads -v /media/wap/HDD/yocto-scarthgap-shared/sstate-cache:/media/wap/HDD/yocto-scarthgap-shared/sstate-cache lea-yocto-scarthgap

FROM ubuntu:22.04

user root

ENV DEBIAN_FRONTEND=noninteractive
ENV LEA_YOCTO_SCARTHGAP_CONTAINER=1

# note: isolate Yocto packaging regressions against a known-good tar revision.
RUN apt-get update && apt-get install -y gawk wget git-core diffstat zip unzip texinfo \
    build-essential crossbuild-essential-arm64 crossbuild-essential-armhf chrpath socat file cpio python3 \
    python3-pip python3-pexpect python3-yaml python3-jsonschema yamllint xz-utils debianutils debconf-utils iputils-ping \
    libsdl1.2-dev xterm tar locales net-tools rsync sudo vim curl zstd \
    liblz4-tool libssl-dev bc lzop libgnutls28-dev efitools git-lfs \
    libglib2.0-0 libxext6 libxtst6 \
    libxft2 libxrender1 libxi6 libsm6 libice6 libfontconfig1 libfreetype6 libdbus-1-3 libnss3 \
    gdb xxd tmux libncurses-dev xvfb xauth bison flex

# inside the container,record the list of installed packages and their versions for reference
# dpkg-query -W -f='${Package}\t${Version}\n' | sort > package-manifest.txt

# make git more forgiving of slow connections (e.g. when downloading Yocto layers)
RUN git config --system http.version HTTP/1.1 && git config --system http.lowSpeedLimit 0 && git config --system http.lowSpeedTime 999999
# for manual resume of interrupted kernel mirror fetches, use this one command repeatedly when needed:
# git -C github.com.beagleboard.linux.git fetch --all --tags --prune --progress
# if the mirror directory does not exist yet, initialize once:
# mkdir -p github.com.beagleboard.linux.git
# git -C github.com.beagleboard.linux.git init --bare
# git -C github.com.beagleboard.linux.git remote add origin https://github.com/beagleboard/linux.git
# then continue with BitBake fetch/build as usual.


RUN pip3 install numpy
RUN pip3 install websockets
RUN pip3 install pyelftools
RUN pip3 install cryptography
RUN python3 -c "import yaml, jsonschema"

RUN locale-gen en_US.UTF-8 && \
    update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8


# Install Quartus Prime Lite 25.1 in a fixed location so the toolchain is
# available directly inside the image.
COPY qinst-lite-linux-25.1std-1129.run /opt/
RUN mkdir -p /tmp/quartus-downloads /tmp/quartus-installer /opt/intelFPGA_lite && \
    chmod +x /opt/qinst-lite-linux-25.1std-1129.run && \
    /opt/qinst-lite-linux-25.1std-1129.run --nox11 --accept --noexec --target /tmp/quartus-installer && \
    xvfb-run -a /tmp/quartus-installer/qinst.sh --cli \
        --download-dir /tmp/quartus-downloads \
        --install-dir /opt/intelFPGA_lite/25.1std \
        --accept-eula \
        --auto-install \
        --bypass \
        --delete-downloads \
        --components quartus,max10 && \
    rm -rf /tmp/quartus-downloads /tmp/quartus-installer /opt/qinst-lite-linux-25.1std-1129.run

ENV QUARTUS_ROOTDIR=/opt/intelFPGA_lite/25.1std/quartus
ENV QSYS_ROOTDIR=/opt/intelFPGA_lite/25.1std/quartus/sopc_builder/bin
ENV QUARTUS_PATH="/opt/intelFPGA_lite/25.1std/quartus/bin:/opt/intelFPGA_lite/25.1std/quartus/sopc_builder/bin:/opt/intelFPGA_lite/25.1std/questa_fse/linux_x86_64:$PATH"

# recent versions of arm-none-eabi-gcc must be installed manually (thanks a lot, ARM!)
COPY arm-gnu-toolchain-12.2.rel1-x86_64-arm-none-eabi.tar.xz /opt
RUN cd /opt && \
    tar -xf arm-gnu-toolchain-12.2.rel1-x86_64-arm-none-eabi.tar.xz && \
    rm arm-gnu-toolchain-12.2.rel1-x86_64-arm-none-eabi.tar.xz
ENV PATH="/opt/arm-gnu-toolchain-12.2.rel1-x86_64-arm-none-eabi/bin:$PATH"

# installing/licensing ADI Sharc tools is a pain (thanks a lot, ADI!)
# license file required at ~/.analog/cces/license.dat
RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y \
    libc6:i386 libncurses5:i386 libstdc++6:i386 libgtk2.0-0:i386 libxtst6:i386 \
    gtk2-engines-murrine:i386 libcanberra-gtk-module:i386 gtk2-engines:i386
COPY adi-CrossCoreEmbeddedStudio-linux-x86-2.10.1.deb /opt
COPY com.analog.crosscore.incubation.blackfin_sharc_linux.stage_2.10.1.202202091957.jar /opt
# wap@boyd:$ debconf-show adi-cces-2.10.1
# debconf: DbDriver "passwords" warning: could not open /var/cache/debconf/passwords.dat: Permission denied
# * adi-cces-2.10.1/read-sla:
# * adi-cces-2.10.1/run-ocd-config: false
#   adi-cces-2.10.1/error-sla:
# * adi-cces-2.10.1/accept-sla: true
RUN echo "adi-cces-2.10.1 adi-cces-2.10.1/accept-sla boolean true" | debconf-set-selections
RUN cd /opt && \
    dpkg -i adi-CrossCoreEmbeddedStudio-linux-x86-2.10.1.deb && \
    unzip com.analog.crosscore.incubation.blackfin_sharc_linux.stage_2.10.1.202202091957.jar support_files.tar.gz && \
    tar xvf support_files.tar.gz -C /opt/analog/cces/2.10.1
RUN chmod -R 777 /opt/analog/cces/2.10.1/ARM/packs
RUN ln -sf /usr/bin/rm /usr/bin/clean

# install version Make-4.4.1 for .WAIT target needed for new fw update scheme
COPY make-4.4.1.tar.gz /opt
RUN cd /opt && \
    tar -xzf make-4.4.1.tar.gz && \
    cd /opt/make-4.4.1 && \
    ./configure && make && make install && \
    rm /opt/make-4.4.1.tar.gz && rm -r /opt/make-4.4.1

# Yocto needs 'source' command for setting up the build environment, so replace
# the 'sh' alias to 'bash' instead of 'dash'.
RUN rm /bin/sh && ln -s bash /bin/sh

# Add your user to sudoers
ARG USER
RUN echo "${USER} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${USER} && \
    chmod 0440 /etc/sudoers.d/${USER}

# Set the arguments for host_id and user_id
ARG host_uid \
    host_gid
RUN groupadd -f -g $host_gid $USER && \
    useradd -g $host_gid -m -s /bin/bash -u $host_uid $USER

# Default runtime working directory (can be overridden by docker run --workdir)
ARG WORKDIR=/home
WORKDIR ${WORKDIR}

# Yocto builds should run as a normal user.
USER $USER

