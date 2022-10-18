ARG BASE_REGISTRY=docker.io
ARG BASE_IMAGE=zarguell/ruby31
ARG BASE_TAG=latest

FROM ${BASE_REGISTRY}/${BASE_IMAGE}:${BASE_TAG}

## THIS IS Iron Bank version of Dockerfile to be submitted to Iron Bank repo for approval, do not spin this up locally

# ------------------------------------------------------------------------------------------------------------
# Per hardening manifest guidance: https://repo1.dso.mil/dsop/dccscr/-/tree/master/hardening%20manifest

USER root

RUN rpm --import "https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-8"

RUN dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm -y

RUN dnf update -y --nodocs && \
    dnf install -y libpq libsqlite3x git sqlite-devel postgresql-devel gcc gcc-c++ make ruby-devel xz patch python39 && \
    dnf clean all && \
    rm -rf /var/cache/yum && \
    dnf remove -y vim-minimal

ADD dradis /dradis

WORKDIR /dradis

#Can't set production without SSL
#ENV RAILS_ENV=production

#Complains without the rake gem setup
RUN gem install rake
RUN gem install bundler

RUN ruby ./bin/setup

RUN chown -R 1001:1001 /dradis

USER 1001

#Bind to all interfaces explicitly as the default is localhost only
CMD ["bundle","exec","rails","server","-b","0.0.0.0"]

# USER 1001
