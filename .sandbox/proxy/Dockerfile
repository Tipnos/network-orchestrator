# Filtering forward proxy: the sandbox's only route to the internet.
FROM alpine:3.20

RUN apk add --no-cache squid

# Runs as `squid`, not root: with cap_drop ALL, squid can't setuid down from
# root. /etc/squid is writable because entrypoint.sh generates the ACL there.
RUN mkdir -p /var/cache/squid /var/log/squid /etc/squid \
    && chown -R squid:squid /var/cache/squid /var/log/squid /etc/squid

COPY squid.conf /etc/squid/squid.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER squid
EXPOSE 3128
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
