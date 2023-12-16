FROM alpine:3.19

RUN adduser --disabled-password alpine-lua && \
    apk update && \
    apk upgrade && \
    apk add luarocks build-base lua5.1-dev && \
    luarocks-5.1 install luacheck

COPY --chmod=755 entrypoint.sh /

USER alpine-lua

ENTRYPOINT [ "/entrypoint.sh" ]