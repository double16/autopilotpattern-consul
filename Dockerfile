FROM alpine:3.7
MAINTAINER Vicko Vitasovic "vickovitasovic@gmail.com"

ENV CONSUL_VERSION="1.0.6" \
    CONTAINERPILOT_VER="3.6.2" CONTAINERPILOT="/etc/containerpilot.json5" \
    SHELL="/bin/bash"

# Alpine packages
RUN apk --no-cache add curl bash ca-certificates jq \
# The Consul binary
    && export CONSUL_CHECKSUM=bcc504f658cef2944d1cd703eda90045e084a15752d23c038400cf98c716ea01 \
    && export archive=consul_${CONSUL_VERSION}_linux_amd64.zip \
    && curl -Lso /tmp/${archive} https://releases.hashicorp.com/consul/${CONSUL_VERSION}/${archive} \
    && echo "${CONSUL_CHECKSUM}  /tmp/${archive}" | sha256sum -c \
    && cd /bin \
    && unzip /tmp/${archive} \
    && chmod +x /bin/consul \
    && rm /tmp/${archive} \
# Add Containerpilot and set its configuration
    && export CONTAINERPILOT_CHECKSUM=b799efda15b26d3bbf8fd745143a9f4c4df74da9 \
    && curl -Lso /tmp/containerpilot.tar.gz \
         "https://github.com/joyent/containerpilot/releases/download/${CONTAINERPILOT_VER}/containerpilot-${CONTAINERPILOT_VER}.tar.gz" \
    && echo "${CONTAINERPILOT_CHECKSUM}  /tmp/containerpilot.tar.gz" | sha1sum -c \
    && tar zxf /tmp/containerpilot.tar.gz -C /usr/local/bin \
    && rm /tmp/containerpilot.tar.gz \
# Add Prometheus exporter
    && curl --fail -sL https://github.com/prometheus/consul_exporter/releases/download/v0.3.0/consul_exporter-0.3.0.linux-amd64.tar.gz |\
    tar -xzO -f - consul_exporter-0.3.0.linux-amd64/consul_exporter > /usr/local/bin/consul_exporter \
    && chmod +x /usr/local/bin/consul_exporter \
    && curl --fail -sL https://github.com/prometheus/node_exporter/releases/download/v0.15.2/node_exporter-0.15.2.linux-amd64.tar.gz |\
    tar -xzO -f - node_exporter-0.15.2.linux-amd64/node_exporter > /usr/local/bin/node_exporter \
    && chmod +x /usr/local/bin/node_exporter

# configuration files and bootstrap scripts
COPY etc/containerpilot.json5 /etc/
COPY etc/consul.hcl /etc/consul/consul.hcl.orig
COPY bin/* /usr/local/bin/

# Put Consul data on a separate volume to avoid filesystem performance issues
# with Docker image layers. Not necessary on Triton, but...
VOLUME ["/data"]

# We don't need to expose these ports in order for other containers on Triton
# to reach this container in the default networking environment, but if we
# leave this here then we get the ports as well-known environment variables
# for purposes of linking.
EXPOSE 8300 8301 8301/udp 8302 8302/udp 8400 8500 53 53/udp

CMD ["/usr/local/bin/containerpilot"]

HEALTHCHECK --interval=60s --timeout=10s --retries=3 CMD curl -f http://127.0.0.1:8500/ || exit 1