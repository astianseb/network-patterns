curl -v --proxy-insecure -x https://10.1.10.100 https://www.wp.pl     <-- FORBIDDEN
curl -v --proxy-insecure -x https://10.1.10.100 https://www.onet.pl   <-- PASS

With TLS inspection
curl -vvv --proxy-insecure -x https://10.1.10.100 --insecure https://www.onet.pl/index.html
