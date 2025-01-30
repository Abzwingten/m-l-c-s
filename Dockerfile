FROM node:16-alpine AS base
RUN apk add --no-cache \
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
    build-base
RUN apk add alpine-sdk bash libc6-compat krb5-dev
RUN apk add npm

ENV PYTHON=/usr/bin/python3
RUN npm install -g node-gyp
RUN npm install  --unsafe-perm -g code-server@4.12.0
FROM base AS sbcl
RUN apk add --no-cache sbcl && \
    curl -O https://beta.quicklisp.org/quicklisp.lisp && \
    sbcl --load quicklisp.lisp \
         --eval '(quicklisp-quickstart:install)' \
         --eval '(ql:add-to-init-file)' \
         --eval '(quit)'

FROM base AS chicken
RUN apk add --no-cache chicken && \
    chicken-install -s r7rs srfi-1 srfi-13

FROM base AS chez
RUN apk add --no-cache build-base ncurses-dev && \
    git clone https://github.com/cisco/ChezScheme && \
    cd ChezScheme && \
    ./configure --prefix=/usr && \
    make -j$(nproc) && \
    make install

FROM base AS guile
RUN apk add --no-cache guile

FROM base AS mal
RUN apk add --no-cache rust cargo && \
    git clone https://github.com/kanaka/mal && \
    cd mal && \
    make MAL_IMPL=rust && \
    cp rust/target/release/mal /usr/bin/mal

FROM base AS final
COPY --from=sbcl /root/quicklisp /root/quicklisp
COPY --from=sbcl /usr/bin/sbcl /usr/bin/sbcl
COPY --from=chicken /usr/local/lib/chicken /usr/local/lib/chicken
COPY --from=chicken /usr/bin/csi /usr/bin/csi
COPY --from=chez /usr/bin/scheme /usr/bin/scheme
COPY --from=guile /usr/bin/guile /usr/bin/guile
COPY --from=mal /usr/bin/mal /usr/bin/mal

RUN code-server --install-extension alanz.commonlisp-vscode && \
    code-server --install-extension sjhuangx.vscode-scheme

RUN apk del gcc musl-dev build-base ncurses-dev rust cargo git make && \
    rm -rf /var/cache/apk/*

# Configure Workspace
WORKDIR /app
CMD ["code-server", "--auth", "none", "--bind-addr", "0.0.0.0:8080"]
