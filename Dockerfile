# Kong package and entrypoint script to be downloaded and chmod +x by CI pipeline

FROM --platform=amd64 ubuntu:22.04

ARG KONG_VERSION

RUN useradd kong

COPY --chown=kong:kong kong-enterprise-edition-${KONG_VERSION}.deb /tmp/kong.deb
COPY --chown=kong:kong opt/certs/kong.crt opt/certs/kong.key /opt/certs/
COPY --chown=kong:kong opt/plugins/ /usr/local/share/lua/5.1/kong/plugins/

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install --yes /tmp/kong.deb \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/kong.deb \
    && chown kong:0 /usr/local/bin/kong \
    && chown -R kong:0 /usr/local/kong \
    && chown -R kong:0 /opt/certs/ \
    && ln -s /usr/local/openresty/luajit/bin/luajit /usr/local/bin/luajit \
    && ln -s /usr/local/openresty/luajit/bin/luajit /usr/local/bin/lua \
    && ln -s /usr/local/openresty/nginx/sbin/nginx /usr/local/bin/nginx \
    && kong version 
   
COPY --chmod=755 docker-entrypoint.sh kong-docker-entrypoint.sh /
   
USER kong

ENTRYPOINT ["/docker-entrypoint.sh"]
   
EXPOSE 8000 8443 8001 8444 8002 8445 8003 8446 8004 8447
   
STOPSIGNAL SIGQUIT
   
HEALTHCHECK --interval=10s --timeout=10s --retries=10 \
    CMD kong health
   
CMD ["kong", "docker-start"]