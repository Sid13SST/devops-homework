#!/bin/bash
run() { echo "\$ $*"; eval "$@" 2>&1; echo; }
sec() { echo; echo "=================================================="; echo "== $1"; echo "=================================================="; echo; }

sec "1. INTERFACE CONFIGURATION"
run "ip addr show"
run "ip -brief addr show"
run "ip link show"
run "ifconfig"
run "hostname"
run "hostname -I"

sec "2. ROUTING"
run "ip route show"
run "ip route get 8.8.8.8"
run "route -n"
run "netstat -rn"

sec "3. CONNECTIVITY TESTING - ping"
run "ping -c 4 8.8.8.8"
run "ping -c 3 google.com"

sec "4. PATH TRACING - traceroute"
run "traceroute -m 8 8.8.8.8"

sec "5. DNS RESOLUTION"
run "nslookup github.com"
run "dig github.com +short"
run "dig github.com A +noall +answer"
run "dig MX google.com +short"
run "host github.com"
run "cat /etc/resolv.conf"
run "cat /etc/hosts"

sec "6. SOCKETS AND LISTENING PORTS"
# start a listener so there is something to see
(nc -l -p 9999 >/dev/null 2>&1 &) ; sleep 1
run "ss -tuln"
run "ss -tulnp"
run "netstat -tuln"
run "ss -s"

sec "7. PORT / SERVICE REACHABILITY"
run "nc -zv github.com 443"
run "nc -zv -w 3 github.com 80"
run "timeout 5 bash -c 'cat < /dev/null > /dev/tcp/github.com/443' && echo 'port 443 reachable via bash /dev/tcp'"

sec "8. HTTP CLIENTS"
run "curl -s -o /dev/null -w 'HTTP %{http_code}  time=%{time_total}s  ip=%{remote_ip}\n' https://api.github.com"
run "curl -sI https://github.com | head -8"
run "wget -q -S --spider https://github.com 2>&1 | head -8"

sec "9. ARP / NEIGHBOUR TABLE"
run "ip neigh show"
run "arp -a"

sec "10. PUBLIC IP AND WHOIS"
run "curl -s https://api.ipify.org; echo"
run "whois github.com | head -12"

sec "11. PACKET CAPTURE (tcpdump)"
echo "\$ tcpdump -i any -c 5 -n icmp   (capturing while pinging in the background)"
(ping -c 6 8.8.8.8 >/dev/null 2>&1 &)
timeout 12 tcpdump -i any -c 5 -n icmp 2>&1 | tail -10
echo

sec "12. NETWORK STATISTICS"
run "netstat -i"
run "ip -s link show eth0"
