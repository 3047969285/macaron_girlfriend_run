#!/usr/bin/env python3
import argparse
import http.server
import ipaddress
import os
from pathlib import Path
import secrets
import ssl
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
CERT_DIR = Path.home() / 'Library' / 'Application Support' / 'Macaron LAN'


def run(*args):
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def addresses():
    result = subprocess.run(['ifconfig'], check=True, capture_output=True, text=True)
    found = set()
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) > 1 and parts[0] == 'inet':
            try:
                address = ipaddress.IPv4Address(parts[1])
            except ipaddress.AddressValueError:
                continue
            if any(address in network for network in (
                ipaddress.ip_network('10.0.0.0/8'),
                ipaddress.ip_network('172.16.0.0/12'),
                ipaddress.ip_network('192.168.0.0/16'),
            )):
                found.add(str(address))
    return sorted(found)


def certificates(ips):
    CERT_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(CERT_DIR, 0o700)
    ca_key = CERT_DIR / 'ca-key.pem'
    ca_cert = CERT_DIR / 'ca.pem'
    ca_install = CERT_DIR / 'macaron-lan-ca.cer'
    server_key = CERT_DIR / 'server-key.pem'
    server_cert = CERT_DIR / 'server.pem'
    if ca_key.exists() != ca_cert.exists():
        raise RuntimeError('局域网证书不完整；请检查证书目录，不会自动覆盖原证书。')
    with tempfile.TemporaryDirectory(prefix='macaron-cert-') as tmp:
        tmp = Path(tmp)
        config = tmp / 'openssl.cnf'
        if not ca_key.exists():
            config.write_text('[req]\ndistinguished_name=dn\n[dn]\n[ca_ext]\nbasicConstraints=critical,CA:TRUE\nkeyUsage=critical,keyCertSign,cRLSign\nsubjectKeyIdentifier=hash\n')
            run('openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-sha256', '-days', '1825', '-subj', '/CN=Macaron LAN Local CA', '-keyout', str(ca_key), '-out', str(ca_cert), '-config', str(config), '-extensions', 'ca_ext')
        os.chmod(ca_key, 0o600)
        run('openssl', 'x509', '-in', str(ca_cert), '-outform', 'DER', '-out', str(ca_install))
        config.write_text('[req]\ndistinguished_name=dn\n[dn]\n[server_ext]\nbasicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth\nsubjectAltName=@alt\n[alt]\nDNS.1=localhost\n' + ''.join(f'IP.{i}={ip}\n' for i, ip in enumerate(['127.0.0.1', *ips], 1)))
        csr = tmp / 'server.csr'
        run('openssl', 'req', '-new', '-newkey', 'rsa:2048', '-nodes', '-sha256', '-subj', '/CN=Macaron LAN', '-keyout', str(server_key), '-out', str(csr), '-config', str(config))
        os.chmod(server_key, 0o600)
        run('openssl', 'x509', '-req', '-in', str(csr), '-CA', str(ca_cert), '-CAkey', str(ca_key), '-set_serial', '0x' + secrets.token_hex(16), '-days', '365', '-sha256', '-extfile', str(config), '-extensions', 'server_ext', '-out', str(server_cert))
    return ca_install, server_cert, server_key


def main():
    parser = argparse.ArgumentParser(description='在局域网通过 HTTPS 提供游戏')
    parser.add_argument('--port', type=int, default=8080)
    args = parser.parse_args()
    if not 1 <= args.port <= 65535:
        parser.error('端口应在 1–65535 之间')
    directory = ROOT / 'build' / 'web'
    if not (directory / 'index.html').is_file():
        raise RuntimeError('找不到 build/web/index.html，请先构建网页。')
    os.umask(0o077)
    ips = addresses()
    ca_install, cert, key = certificates(ips)
    handler = lambda *a, **kw: http.server.SimpleHTTPRequestHandler(*a, directory=str(directory), **kw)
    server = http.server.ThreadingHTTPServer(('0.0.0.0', args.port), handler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(cert, key)
    server.socket = context.wrap_socket(server.socket, server_side=True)
    print('局域网 HTTPS 地址（手机与 Mac 连接同一 Wi-Fi）：', flush=True)
    for ip in ips:
        print(f'  https://{ip}:{args.port}/', flush=True)
    if not ips:
        print('  未找到局域网地址，请检查 Wi-Fi。', flush=True)
    print(f'首次使用：通过隔空投送把证书发送到 iPhone：{ca_install}', flush=True)
    print('在 iPhone「设置 → 已下载描述文件」安装后，在「设置 → 通用 → 关于本机 → 证书信任设置」信任该证书。', flush=True)
    print('只在自己控制的设备上信任此证书；私钥留在 Mac 上，不要分享。', flush=True)
    print('手机打开 HTTPS 地址，等待“离线资源准备完成”，再添加到主屏幕。按 Ctrl+C 停止服务。', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        raise SystemExit(f'局域网启动失败：{error}') from error
