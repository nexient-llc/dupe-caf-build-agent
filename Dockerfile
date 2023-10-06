FROM public.ecr.aws/codebuild/amazonlinux2-x86_64-standard:5.0 AS core

# Core utilities
RUN set -ex \
    && yum install -y -q openssh-clients \
    && mkdir -p ~/.ssh \
    && mkdir -p /opt/tools \
    && mkdir -p /codebuild/image/config \
    && touch ~/.ssh/known_hosts \
    && ssh-keyscan -t rsa,dsa,ed25519,ecdsa -H github.com >> ~/.ssh/known_hosts \
    && ssh-keyscan -t rsa,dsa,ed25519,ecdsa -H bitbucket.org >> ~/.ssh/known_hosts \
    && chmod 600 ~/.ssh/known_hosts \
    && yum groupinstall -y -q "Development tools" \
    && yum install -y -q \
        amazon-ecr-credential-helper git wget bzip2 bzip2-devel ncurses ncurses-devel jq \
        libffi-devel sqlite-devel docker \
    && yum install -q -y gnupg2 --best --allowerasing

# repo
RUN curl https://storage.googleapis.com/git-repo-downloads/repo -o /usr/bin/repo \
    && chmod a+rx /usr/bin/repo

# yq
RUN wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq \
    && chmod +x /usr/bin/yq

### End of target: core ### 

FROM core AS tools

# Cleanup
RUN rm -fr /tmp/* /var/tmp/*

# Python
ENV PYTHON_VERSION="3.9.16"
ENV PYTHON_PIP_VERSION=21.3.1
ENV PYYAML_VERSION=5.4.1

COPY tools/python/$PYTHON_VERSION /root/.pyenv/plugins/python-build/share/python-build/$PYTHON_VERSION
RUN env PYTHON_CONFIGURE_OPTS="--enable-shared --with-openssl=/usr/include/openssl" pyenv install $PYTHON_VERSION && rm -rf /tmp/*
RUN pyenv global  $PYTHON_VERSION
RUN set -ex \
    && pip3 install --no-cache-dir --upgrade --force-reinstall "pip==$PYTHON_PIP_VERSION" \
    && pip3 install --no-cache-dir --upgrade "PyYAML==$PYYAML_VERSION" \
    && pip3 install --no-cache-dir --upgrade 'setuptools==57.5.0' wheel awscli

ARG TOOLS_DIR="/usr/local/opt"

ENV TOOLS_DIR="${TOOLS_DIR}" \
    BUILD_ACTIONS_DIR="${TOOLS_DIR}/caf-build-agent/components/build-actions"

RUN mkdir -p ${TOOLS_DIR}/caf-build-agent
WORKDIR ${TOOLS_DIR}/caf-build-agent/
COPY ./.tool-versions ${TOOLS_DIR}/caf-build-agent/.tool-versions
COPY ./asdf-setup.sh ${TOOLS_DIR}/caf-build-agent/asdf-setup.sh
RUN ${TOOLS_DIR}/caf-build-agent/asdf-setup.sh

### End of target: tools  ### 

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
