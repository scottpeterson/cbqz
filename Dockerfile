FROM alpine:latest
MAINTAINER Gryphon Shafer <g@cbqz.org>

WORKDIR /cbqz
COPY cpanfile .

RUN apk --no-cache add perl perl-dbd-mysql && \
    apk --no-cache add --virtual .build-dependencies build-base curl wget perl-dev mariadb-dev && \
    curl -sL http://xrl.us/cpanm > cpanm && chmod +x cpanm && \
    ./cpanm -n -f --installdeps . && rm -rf ~/.cpanm && \
    apk del .build-dependencies && rm ./cpanm

VOLUME /cbqz
EXPOSE 3000

CMD rm runtime/hypnotoad.pid
CMD hypnotoad -f app.pl
