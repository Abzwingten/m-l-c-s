FROM node:20-alpine AS code-builder
RUN apk update && \
    apk upgrade
RUN apk add bash git alpine-sdk quilt krb5-dev libx11-dev \
      libxkbfile-dev libstdc++ libc6-compat libsecret-dev jq rsync
RUN git clone --recurse-submodules --shallow-submodules   \
      --depth 1 https://github.com/coder/code-server.git  \
      /code-server
RUN cd /code-server && quilt push -a
RUN cd /code-server && npm install
RUN cd /code-server && npm run build
RUN cd /code-server && VERSION='0.0.0' npm run build:vscode
RUN cd /code-server && npm run release
RUN cd /code-server && npm run release:standalone


FROM alpine:latest AS base
RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
    git \
    curl \
    make \
    gcc \
    g++ \
    python3 \
    libstdc++ \
    linux-headers \
    autoconf \
    automake \
    libtool \
    pkgconf \
    build-base \
    sudo 



FROM base AS sbcl
RUN apk add --no-cache sbcl && \
    curl -O https://beta.quicklisp.org/quicklisp.lisp && \
    sbcl --load quicklisp.lisp \
         --eval '(quicklisp-quickstart:install)' \
         --eval '(ql:add-to-init-file)' \
         --eval '(quit)'

FROM base AS chez
RUN apk add --no-cache build-base ncurses-dev && \
    git clone https://github.com/cisco/ChezScheme && \
    cd ChezScheme && \
    ./configure --prefix=/usr --disable-x11 && \
    make -j$(nproc) && \
    make install

FROM base AS guile
RUN apk add --no-cache guile


FROM base AS final
COPY --from=sbcl /root/quicklisp /root/quicklisp
COPY --from=sbcl /usr/bin/sbcl /usr/bin/sbcl
COPY --from=chez /usr/bin/scheme /usr/bin/scheme
COPY --from=guile /usr/bin/guile /usr/bin/guile
COPY --from=code-builder /code-server/release-standalone /usr/bin/code-server


RUN code-server --install-extension alanz.commonlisp-vscode && \
    code-server --install-extension sjhuangx.vscode-scheme

RUN apk del gcc musl-dev build-base ncurses-dev rust cargo git make && \
    rm -rf /var/cache/apk/*
    

# Configure Workspace
WORKDIR /app
CMD ["code-server", "--auth", "none", "--bind-addr", "0.0.0.0:8080"]
