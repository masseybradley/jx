# syntax = docker/dockerfile:experimental
FROM golang:1.12.9-buster as build

ENV GOPATH /go
ENV GOOS linux
ENV GOARCH amd64
ENV JX_HOME /home/jx/.jx

VOLUME ["/home/jx/.jx"]

RUN apt-get update && \
    apt-get install -y \
        git \
        openssh-client \
        make \
        go-dep \
        python3.7 \
        python3-pip \
        python3.7-dev \
        python3-setuptools \
        python3-wheel \
        bash-completion \
        software-properties-common \
        apt-transport-https \
        curl

RUN curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
RUN add-apt-repository "deb https://apt.kubernetes.io/ kubernetes-xenial main" && \
    apt-get update && \
    apt-get install -y \
        kubelet \
        kubeadm \
        kubectl

RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" |tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
RUN apt-get update && \
    apt-get install -y \
        google-cloud-sdk \
        google-cloud-sdk-app-engine-python \
        google-cloud-sdk-app-engine-python-extras

RUN python3 -m pip install \
        pre-commit \
        detect-secrets \
        ipython

RUN curl https://get.helm.sh/helm-v3.1.1-linux-386.tar.gz | tar xvz --strip-components 1 -C /usr/local/bin

RUN mkdir -p -m 0600 ~/.ssh && \
    ssh-keyscan github.com >> ~/.ssh/known_hosts

WORKDIR /go/src/github.com/jenkins-x/jx

COPY . .

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    make build && \
    mv build/jx /usr/local/bin/jx

RUN groupadd -g 1000 bob && \
    useradd -u 1000 -g bob -d /home/bob -m -k /etc/skel -s /bin/bash bob

RUN sed -i -e "s/#alias/alias/g" /home/bob/.bashrc && \
    echo "source <(jx completion bash)\nsource <(helm completion bash)\nsource <(kubectl completion bash)" >> /home/bob/.bashrc

WORKDIR /home/bob/.jx
RUN chown -R 1000:1000 /go/src /home/bob/.jx

USER bob
ENTRYPOINT ["/usr/bin/jx"]
