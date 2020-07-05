FROM alpine

RUN apk add --no-cache tini iptables ip6tables curl

ADD configure-firewall.sh /bin
RUN chmod +x /bin/configure-firewall.sh

RUN mkdir /lists
RUN curl https://www.spamhaus.org/drop/drop.txt 2> /dev/null | sed 's/;.*//' > /lists/drop.txt
RUN curl https://www.spamhaus.org/drop/dropv6.txt 2> /dev/null | sed 's/;.*//' > /lists/dropv6.txt

ENTRYPOINT ["/sbin/tini", "--"]

CMD ["/bin/configure-firewall.sh"]
