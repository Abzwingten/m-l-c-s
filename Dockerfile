FROM jeanblanchard/alpine-glibc:3.19

ENV \
   # container/su-exec UID \
   EUID=1001 \
   # container/su-exec GID \
   EGID=1001 \
   # container/su-exec user name \
   EUSER=vscode \
   # container/su-exec group name \
   EGROUP=vscode \
   # should user shell set to nologin? (yes/no) \
   ENOLOGIN=no \
   # container user home dir \
   EHOME=/home/vscode \
   # code-server version \
   VERSION=4.96.4

COPY code-server /usr/bin/
RUN chmod +x /usr/bin/code-server

# Install dependencies
RUN \
   apk --no-cache --update add \
   bash \
   curl \
   git \
   gnupg \
   nodejs \
   openssh-client \
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

RUN \
   wget https://github.com/cdr/code-server/releases/download/v$VERSION/code-server-$VERSION-linux-amd64.tar.gz && \
   tar x -zf code-server-$VERSION-linux-amd64.tar.gz && \
   rm code-server-$VERSION-linux-amd64.tar.gz && \
   rm code-server-$VERSION-linux-amd64/bin/code-server && \
   rm code-server-$VERSION-linux-amd64/lib/node && \
   mv code-server-$VERSION-linux-amd64 /usr/lib/code-server #&& \
   # sed -i 's/"$ROOT\/lib\/node"/node/g'  /usr/lib/code-server/bin/code-server


RUN apk add --no-cache sbcl && \
    curl -O https://beta.quicklisp.org/quicklisp.lisp && \
    sbcl --load quicklisp.lisp \
         --eval '(quicklisp-quickstart:install)' \
         --eval '(ql:add-to-init-file)' \
         --eval '(quit)'

RUN apk add --no-cache build-base ncurses-dev && \
    git clone https://github.com/cisco/ChezScheme && \
    cd ChezScheme && \
    ./configure --prefix=/usr --disable-x11 && \
    make -j$(nproc) && \
    make install

RUN apk add --no-cache guile
RUN  /usr/bin/code-server --install-extension alanz.commonlisp-vscode && \
     /usr/bin/code-server --install-extension sjhuangx.vscode-scheme



ENTRYPOINT ["entrypoint-su-exec", "code-server"]
CMD ["--bind-addr 0.0.0.0:8080"]

