FROM ubuntu:16.04

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]
