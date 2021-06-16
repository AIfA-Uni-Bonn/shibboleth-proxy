FROM debian:buster AS builder

RUN apt-get update && \
    apt-get install -y \
        wget gpg sudo \
        build-essential unzip git mercurial \
        libpcre3-dev zlib1g-dev libssl-dev \
        devscripts debhelper dpkg-dev quilt lsb-release \
        libxml2-utils xsltproc

# nginx packages for Shibboleth FastCGI
# https://github.com/nginx-shib/nginx-http-shibboleth
RUN wget https://hg.nginx.org/pkg-oss/raw-file/e770ce85c465/build_module.sh && \
    chmod a+x build_module.sh && \
    ./build_module.sh -y -s -v 1.19.5 -o / https://github.com/nginx-shib/nginx-http-shibboleth/archive/a386c1844d9a3ed7dbe867fb5c937ccc6975a518.zip && \
    ./build_module.sh -y -s -v 1.19.5 -o / https://github.com/openresty/headers-more-nginx-module/archive/d6d7ebab3c0c5b32ab421ba186783d3e5d2c6a17.zip

# https://github.com/nginxinc/docker-nginx/blob/master/stable/stretch/Dockerfile
FROM nginx:1.19.5-perl

USER root

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get install -y \
        wget gpg sudo

RUN wget https://pkg.switch.ch/switchaai/debian/dists/buster/main/binary-all/misc/switchaai-apt-source_1.0.0_all.deb && \
    dpkg -i ./switchaai-apt-source_1.0.0_all.deb

RUN apt-mark hold nginx && \
    apt-get update && \
    apt-get install -y \
        apt-utils \
        fakeroot \
        supervisor \
        init-system-helpers \
        libxerces-c3.2 \
        shibboleth-sp-utils \
        shibboleth

COPY --from=builder /*.deb ./
RUN dpkg -i *.deb

# add new installed modules
RUN sed -i "1iload_module modules/ngx_http_headers_more_filter_module.so;" /etc/nginx/nginx.conf
RUN sed -i "1iload_module modules/ngx_http_shibboleth_module.so;" /etc/nginx/nginx.conf

# Copy supervisor config files
COPY etc/supervisor /etc/supervisor

EXPOSE 80 443

#COPY etc/shibboleth/ /etc/shibboleth/
COPY etc/nginx/nginx.conf /etc/nginx/
COPY etc/nginx/proxy_params /etc/nginx/
COPY etc/nginx/shib_clear_headers /etc/nginx/
COPY etc/nginx/shib_fastcgi_params /etc/nginx/
COPY etc/nginx/default.conf /etc/nginx/conf.d

# Shibboleth folders
RUN mkdir -p /run/shibboleth/ /var/log/shibboleth/ && \
    chown -R _shibd:_shibd /run/shibboleth/ /var/log/shibboleth/

# CMD ["nginx", "-g", "daemon off;"]
# start supervisord after all volumes are mounted => run command in compose file
CMD ["/usr/bin/supervisord", "--nodaemon", "--configuration", "/etc/supervisor/supervisord.conf"]
