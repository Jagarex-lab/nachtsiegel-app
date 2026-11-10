#!/usr/bin/env python3
"""Static HTTPS preview. Supply a certificate trusted by the test device."""
import argparse
import functools
import http.server
import pathlib
import ssl


class PreviewHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # ZIP timestamps are fixed for reproducibility; avoid stale preview HTML.
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', default='.')
    parser.add_argument('--cert', required=True)
    parser.add_argument('--key', required=True)
    parser.add_argument('--bind', default='127.0.0.1')
    parser.add_argument('--port', type=int, default=9443)
    args = parser.parse_args()
    directory = pathlib.Path(args.directory).resolve()
    if not (directory / 'index.html').is_file():
        parser.error('--directory must contain the unpacked index.html')
    if pathlib.Path(args.key).resolve().is_relative_to(directory):
        parser.error('Keep the private key outside the served directory')
    handler = functools.partial(PreviewHandler, directory=str(directory))
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(args.cert, args.key)
    with http.server.ThreadingHTTPServer((args.bind, args.port), handler) as server:
        server.socket = context.wrap_socket(server.socket, server_side=True)
        print(f'HTTPS preview on port {args.port}; open the certificate hostname/IP.', flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == '__main__':
    main()
