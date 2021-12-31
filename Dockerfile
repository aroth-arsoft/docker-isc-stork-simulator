
FROM debian:10-slim AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
    bison flex automake libtool pkg-config build-essential ca-certificates cmake git


RUN apt-get install -y --no-install-recommends --no-install-suggests \
    libldns-dev libgnutls28-dev

# Install libuv for DNS testing.
RUN mkdir -p /tmp/libuv && cd /tmp/libuv && git clone https://github.com/libuv/libuv.git && cd libuv && sh autogen.sh && ./configure && make && make install

# Install flamethrower for DNS testing.
RUN mkdir -p /tmp/flamethrower && cd /tmp/flamethrower && git clone https://github.com/DNS-OARC/flamethrower && cd flamethrower && git checkout v0.10.2 && mkdir build && cd build && cmake .. && make && make install


FROM docker-isc-kea-full:unstable
MAINTAINER Andreas Roth "aroth@arsoft-online.com"
ARG BUILD_DATE
ARG VCS_REF
LABEL org.label-schema.build-date=$BUILD_DATE \
    org.label-schema.license=GPL-3.0 \
    org.label-schema.name=stork \
    org.label-schema.vcs-ref=$VCS_REF \
    org.label-schema.vcs-url=https://github.com/aroth-arsoft/docker-stork

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends --no-install-suggests -y curl python3 python3-pip libgnutls30 libldns2 dnsutils && \
    apt-get clean && \
    rm -rf /usr/share/doc/* /usr/share/man/* /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=builder /usr/lib/x86_64-linux-gnu/libuv.so.1 /usr/lib/x86_64-linux-gnu/libuv.so.1
COPY --from=builder /usr/local/bin/flame /usr/local/bin/

RUN mkdir -p /sim && \
    curl -s  --output /sim/stork-master.tar.gz https://gitlab.isc.org/isc-projects/stork/-/archive/master/stork-master.tar.gz?path=tests/sim && \
    tar xfz /sim/stork-master.tar.gz -C /sim && \
    rm /sim/stork-master.tar.gz && \
    mv /sim/stork-master-tests-sim/tests/sim/* /sim

RUN pip3 install -r /sim/requirements.txt

WORKDIR /sim

EXPOSE 5000

ENV FLASK_ENV=development \
    FLASK_APP=sim.py \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8
# Start flask app.
ENTRYPOINT ["flask", "run", "--host", "0.0.0.0"]
