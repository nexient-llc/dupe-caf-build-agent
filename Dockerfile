FROM public.ecr.aws/amazonlinux/amazonlinux:2 AS core

# Core utilities
RUN set -ex \
    && yum install -y -q openssh-clients \
    && mkdir ~/.ssh \
    && mkdir -p /opt/tools \
    && mkdir -p /codebuild/image/config \
    && touch ~/.ssh/known_hosts \
    && ssh-keyscan -t rsa,dsa,ed25519,ecdsa -H github.com >> ~/.ssh/known_hosts \
    && ssh-keyscan -t rsa,dsa,ed25519,ecdsa -H bitbucket.org >> ~/.ssh/known_hosts \
    && chmod 600 ~/.ssh/known_hosts \
    && amazon-linux-extras install epel -y \
    && amazon-linux-extras enable docker \
    && yum groupinstall -y -q "Development tools" \
    && yum install -y -q \
        amazon-ecr-credential-helper git wget bzip2 ncurses openssl11 openssl11-devel jq \
        libffi-devel repo libsqlite3x-devel.x86_64 yq docker

RUN wget https://dist.libuv.org/dist/v1.43.0/libuv-v1.43.0.tar.gz \
    && tar -zxf libuv-v1.43.0.tar.gz \
    && cd libuv-v1.43.0/ \
    && ./autogen.sh \
    && ./configure \
    && make \
    && make install

# Buildx
RUN mkdir -vp /usr/libexec/docker/cli-plugins/ \
    && curl --silent -L "https://github.com/docker/buildx/releases/download/v0.10.0/buildx-v0.10.0.linux-amd64" > /usr/libexec/docker/cli-plugins/docker-buildx \
    && chmod a+x /usr/libexec/docker/cli-plugins/docker-buildx

### End of target: core ### 

FROM core AS env

# pyenv
RUN curl https://pyenv.run | bash
ENV PATH="/root/.pyenv/shims:/root/.pyenv/bin:$PATH"

### End of target: env  ### 

FROM env AS tools

# Install Maven
ENV MAVEN_HOME="/opt/maven" \
    MAVEN_VERSION=3.9.1 \
    MAVEN_DOWNLOAD_SHA512="d3be5956712d1c2cf7a6e4c3a2db1841aa971c6097c7a67f59493a5873ccf8c8b889cf988e4e9801390a2b1ae5a0669de07673acb090a083232dbd3faf82f3e3"

ARG MAVEN_CONFIG_HOME="/root/.m2"

RUN set -ex \
    && mkdir -p $MAVEN_HOME \
    && curl -LSso /var/tmp/apache-maven-$MAVEN_VERSION-bin.tar.gz https://archive.apache.org/dist/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz \
    && echo "$MAVEN_DOWNLOAD_SHA512 /var/tmp/apache-maven-$MAVEN_VERSION-bin.tar.gz" | sha512sum -c - \
    && tar xzf /var/tmp/apache-maven-$MAVEN_VERSION-bin.tar.gz -C $MAVEN_HOME --strip-components=1 \
    && rm /var/tmp/apache-maven-$MAVEN_VERSION-bin.tar.gz \
    && update-alternatives --install /usr/bin/mvn mvn /opt/maven/bin/mvn 10000 \
    && mkdir -p $MAVEN_CONFIG_HOME

# Cleanup
RUN rm -fr /tmp/* /var/tmp/*

# Python 3.9
ENV PYTHON_39_VERSION="3.9.16"
ENV PYTHON_PIP_VERSION=21.3.1
ENV PYYAML_VERSION=5.4.1

COPY tools/python/$PYTHON_39_VERSION /root/.pyenv/plugins/python-build/share/python-build/$PYTHON_39_VERSION
RUN   env PYTHON_CONFIGURE_OPTS="--enable-shared" pyenv install $PYTHON_39_VERSION && rm -rf /tmp/*
RUN   pyenv global  $PYTHON_39_VERSION
RUN set -ex \
    && pip3 install --no-cache-dir --upgrade --force-reinstall "pip==$PYTHON_PIP_VERSION" \
    && pip3 install --no-cache-dir --upgrade "PyYAML==$PYYAML_VERSION" \
    && pip3 install --no-cache-dir --upgrade 'setuptools==57.5.0' wheel awscli

### End of target: runtimes  ### 

FROM tools AS caf

ARG GIT_USERNAME \
    GIT_TOKEN \
    GIT_SERVER_URL \
    TOOLS_DIR="/usr/local/opt"

ENV TOOLS_DIR="${TOOLS_DIR}" \
    BUILD_ACTIONS_DIR="${TOOLS_DIR}/caf-build-agent/components/build-actions"

# Install CAF

RUN git clone "https://${GIT_USERNAME}:${GIT_TOKEN}@${GIT_SERVER_URL}/scm/dso/git-repo.git" "${TOOLS_DIR}/git-repo" \
    && cd "${TOOLS_DIR}/git-repo" \
    && chmod +x "repo"

ENV PATH="$PATH:${TOOLS_DIR}/git-repo:${TOOLS_DIR}/.asdf:${BUILD_ACTIONS_DIR}" \
    JOB_NAME="${GIT_USERNAME}" \
    JOB_EMAIL="${GIT_USERNAME}@nextgen.com" \
    IS_PIPELINE=true \
    IS_AUTHENTICATED=true

COPY "./Makefile" "${TOOLS_DIR}/caf-build-agent/Makefile"

RUN cd /usr/local/opt/caf-build-agent \
    && make git-config \
    && make git-auth \
    && make configure \ 
    && rm -rf $HOME/.gitconfig

### End of target: caf  ###
