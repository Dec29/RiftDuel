#!/bin/bash
# Run beside the templates on the server; leaves TLS evidence in a private directory.
set -eu
cd "$(dirname "$0")"
work=$(mktemp -d "$PWD/verify-XXXXXXXX")
chmod 700 "$work"
relay_pid=
nginx_pid=
cleanup() {
    if test -n "$nginx_pid"; then kill "$nginx_pid" 2>/dev/null || true; wait "$nginx_pid" 2>/dev/null || true; fi
    if test -n "$relay_pid"; then kill "$relay_pid" 2>/dev/null || true; wait "$relay_pid" 2>/dev/null || true; fi
}
trap cleanup EXIT
openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
    -keyout "$work/test-key.pem" -out "$work/test-cert.pem" \
    -subj '/CN=RiftDuel local deployment test' \
    -addext 'subjectAltName=IP:134.175.45.75' > "$work/openssl.log" 2>&1
chmod 600 "$work/test-key.pem"
mkdir -p "$work/acme/.well-known/acme-challenge"
printf 'challenge-ok' > "$work/acme/.well-known/acme-challenge/test"
sed -e 's/PUBLIC_IP/134.175.45.75/g' \
    -e 's/listen 80;/listen 127.0.0.1:8081;/' \
    -e "s|/var/lib/riftduel/acme|$work/acme|g" \
    nginx-http.conf.example > "$work/http.conf"
sed -e 's/PUBLIC_IP/134.175.45.75/g' \
    -e 's/listen 443 ssl;/listen 127.0.0.1:8443 ssl;/' \
    -e "s|/etc/letsencrypt/live/riftduel-ip/fullchain.pem|$work/test-cert.pem|g" \
    -e "s|/etc/letsencrypt/live/riftduel-ip/privkey.pem|$work/test-key.pem|g" \
    nginx-tls.conf.example > "$work/tls.conf"
cat > "$work/nginx.conf" <<EOF
pid $work/nginx.pid;
error_log $work/nginx.log;
events { worker_connections 256; }
http {
    client_body_temp_path $work/body;
    proxy_temp_path $work/proxy;
    fastcgi_temp_path $work/fastcgi;
    uwsgi_temp_path $work/uwsgi;
    scgi_temp_path $work/scgi;
    include $work/http.conf;
    include $work/tls.conf;
}
EOF
/usr/sbin/nginx -t -p "$work/" -c "$work/nginx.conf"
../riftduel-relay -listen 127.0.0.1:8080 > "$work/relay.log" 2>&1 &
relay_pid=$!
/usr/sbin/nginx -p "$work/" -c "$work/nginx.conf" -g 'daemon off;' &
nginx_pid=$!
ready=0
for attempt in $(seq 1 30); do
    if curl --noproxy '*' --silent --fail --cacert "$work/test-cert.pem" \
        --resolve 134.175.45.75:8443:127.0.0.1 https://134.175.45.75:8443/healthz > "$work/health.txt"; then ready=1; break; fi
    sleep 0.1
done
test "$ready" = 1
test "$(cat "$work/health.txt")" = ok
test "$(curl --noproxy '*' --silent http://127.0.0.1:8081/.well-known/acme-challenge/test)" = challenge-ok
test "$(curl --noproxy '*' --silent -o /dev/null -w '%{http_code}' http://127.0.0.1:8081/ws)" = 404
python3 - "$work/test-cert.pem" <<'PY'
import base64, hashlib, json, os, socket, ssl, struct, sys
ctx = ssl.create_default_context(cafile=sys.argv[1])
def connect(origin=False):
    s = ctx.wrap_socket(socket.create_connection(('127.0.0.1', 8443), timeout=3), server_hostname='134.175.45.75')
    key = base64.b64encode(os.urandom(16)).decode()
    request = f'GET /ws HTTP/1.1\r\nHost: 134.175.45.75\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n'
    if origin: request += 'Origin: https://example.com\r\n'
    s.sendall((request + '\r\n').encode())
    response = b''
    while not response.endswith(b'\r\n\r\n'): response += s.recv(1)
    return s, key, response
def send(s, m):
    data = json.dumps(m, separators=(',', ':')).encode()
    mask = os.urandom(4)
    assert len(data) < 126
    s.sendall(bytes([0x81, 0x80 | len(data)]) + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))
def exact(s, n):
    data = b''
    while len(data) < n:
        part = s.recv(n - len(data))
        assert part, 'unexpected EOF'
        data += part
    return data
def read(s):
    header = exact(s, 2)
    assert header[0] == 0x81 and not header[1] & 0x80
    size = header[1] & 127
    if size == 126: size = struct.unpack('!H', exact(s, 2))[0]
    elif size == 127: size = struct.unpack('!Q', exact(s, 8))[0]
    assert size <= 32768
    return json.loads(exact(s, size))
s, key, response = connect()
assert response.startswith(b'HTTP/1.1 101 '), response
accept = base64.b64encode(hashlib.sha1((key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest())
assert b'sec-websocket-accept: ' + accept.lower() in response.lower()
send(s, dict(v=1, type='hello', seq=1, build='a' * 64))
assert read(s) == dict(v=1, type='hello', seq=1)
send(s, dict(v=1, type='create', seq=2))
created = read(s)
assert created['type'] == 'created' and created['seq'] == 2 and len(created['invite']) == 32
s.close()
s, _, response = connect(origin=True)
assert response.startswith(b'HTTP/1.1 403 '), response
s.close()
print('TLS chain/IP SAN, WebSocket 101, hello/create and Origin rejection: OK')
PY
echo 'DEPLOY_LOCAL_VERIFY_OK'
