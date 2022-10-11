ARG BASE_REGISTRY=docker.io
ARG BASE_IMAGE=zarguell/ubi8
ARG BASE_TAG=latest

FROM ${BASE_REGISTRY}/${BASE_IMAGE}:${BASE_TAG}

WORKDIR /opt/setup

## THIS IS Iron Bank version of Dockerfile to be submitted to Iron Bank repo for approval, do not spin this up locally

# ------------------------------------------------------------------------------------------------------------
# Per hardening manifest guidance: https://repo1.dso.mil/dsop/dccscr/-/tree/master/hardening%20manifest

# ----- OR ----- if installing without the hardening_manifest downloading things for us
COPY traefik.tar.gz /opt/traefik.tar.gz

USER root

RUN dnf update -y --nodocs && \
    dnf install -y libpq libsqlite3x git gem ruby && \
    dnf clean all && \
    rm -rf /var/cache/yum && \
    dnf remove -y vim-minimal

# clone dradis
RUN git clone --depth=1 https://github.com/dradis/dradis-ce.git

WORKDIR /dradis-ce

#Can't set production without SSL
#ENV RAILS_ENV=production

#Complains without the rake gem setup
RUN gem install rake
RUN gem install bundler

RUN ruby bin/setup

#Bind to all interfaces explicitly as the default is localhost only
CMD ["bundle","exec","rails","server","-b","0.0.0.0"]

# USER 1001
