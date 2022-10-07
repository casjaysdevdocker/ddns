FROM casjaysdevdocker/alpine:latest as ddnsbase
LABEL author="CasjaysDev" \
  email="<docker-admin@casjaysdev.com>" \
  version="1.0.0" \
  description="dynamic-dns server"

RUN apk update --no-cache && apk add --no-cache dhcp-server-vanilla radvd bind bash php8 tftp-hpa tor torsocks
RUN rm -Rf /var/cache/apk/* /etc/named* /etc/bind* /etc/dhcpd* /etc/radvd* /etc/tor* /bin/ash
RUN ln -sf /bin/bash /bin/ash

FROM ddnsbase
ARG BUILD_DATE="$(date +'%Y-%m-%d %H:%M')"

LABEL \
  org.label-schema.name="ddns" \
  org.label-schema.description="My Dynamic DNS server" \
  org.label-schema.url="https://hub.docker.com/r/casjaysdevdocker/ddns" \
  org.label-schema.vcs-url="https://github.com/casjaysdevdocker/ddns" \
  org.label-schema.build-date=$BUILD_DATE \
  org.label-schema.version=$BUILD_DATE \
  org.label-schema.vcs-ref=$BUILD_DATE \
  org.label-schema.license="WTFPL" \
  org.label-schema.vcs-type="Git" \
  org.label-schema.schema-version="1.0" \
  org.label-schema.vendor="CasjaysDev" \
  maintainer="CasjaysDev <docker-admin@casjaysdev.com>"

ENV HOSTNAME ddns
EXPOSE 53 53/udp 67 67/udp 69 69/udp 80 546 546/udp 8053 8053/udp 9050 9050/udp

COPY ./files /var/lib/ddns
COPY ./bin/entrypoint.sh /usr/local/bin/entrypoint-ddns.sh

VOLUME ["/data", "/config"]

HEALTHCHECK --interval=15s --timeout=3s CMD ["/usr/local/bin/entrypoint-ddns.sh","--health"]
ENTRYPOINT ["/usr/local/bin/entrypoint-ddns.sh"]
