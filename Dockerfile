FROM ubuntu:16.04

RUN apt-get update \
    && apt-get install -y jq \
    && apt-get clean

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]