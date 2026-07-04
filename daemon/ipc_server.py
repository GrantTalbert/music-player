"""
ipc_server.py - a tiny newline-delimited-JSON protocol server over a
unix socket, so the Quickshell (QML) GUI can talk to this daemon.

Protocol
--------
Client -> daemon (one JSON object per line):
    {"id": 1, "cmd": "play_pause"}
    {"id": 2, "cmd": "seek", "position": 42.5}

Daemon -> client, in response to a request:
    {"id": 1, "ok": true, "result": {...}}
    {"id": 1, "ok": false, "error": "message"}

Daemon -> client, unsolicited (pushed to every connected client):
    {"event": "snapshot", "data": {...}}   # sent right after connect
    {"event": "state", "data": {...}}      # play/pause/track/queue changes
    {"event": "position", "data": {...}}   # ~1x/second while playing
    {"event": "library", "data": {...}}
    {"event": "playlists", "data": {...}}
    {"event": "favorites", "data": {...}}
"""
from __future__ import annotations

import json
import logging
import os
import socketserver
import threading
from pathlib import Path
from typing import Callable

log = logging.getLogger("ipc")


class Broadcaster:
    def __init__(self):
        self._clients: set["ClientHandler"] = set()
        self._lock = threading.Lock()

    def register(self, client: "ClientHandler"):
        with self._lock:
            self._clients.add(client)

    def unregister(self, client: "ClientHandler"):
        with self._lock:
            self._clients.discard(client)

    def broadcast(self, event: str, data):
        line = json.dumps({"event": event, "data": data}, ensure_ascii=False) + "\n"
        with self._lock:
            clients = list(self._clients)
        for c in clients:
            c.send_raw(line)


class ClientHandler(socketserver.StreamRequestHandler):
    def setup(self):
        super().setup()
        self._write_lock = threading.Lock()

    def send_raw(self, line: str):
        try:
            with self._write_lock:
                self.wfile.write(line.encode("utf-8"))
                self.wfile.flush()
        except OSError:
            pass

    def handle(self):
        server: IpcServer = self.server
        server.broadcaster.register(self)
        try:
            server.send_snapshot(self)
            while True:
                raw = self.rfile.readline()
                if not raw:
                    break
                raw = raw.strip()
                if not raw:
                    continue
                try:
                    msg = json.loads(raw.decode("utf-8"))
                except Exception as e:
                    self.send_raw(json.dumps({"ok": False, "error": f"bad json: {e}"}) + "\n")
                    continue
                self._dispatch(server, msg)
        except (ConnectionResetError, BrokenPipeError):
            pass
        finally:
            server.broadcaster.unregister(self)

    def _dispatch(self, server: "IpcServer", msg: dict):
        req_id = msg.get("id")
        cmd = msg.get("cmd")
        handler = server.handlers.get(cmd)
        if handler is None:
            self.send_raw(json.dumps({"id": req_id, "ok": False,
                                       "error": f"unknown command: {cmd}"}) + "\n")
            return
        try:
            result = handler(msg)
            self.send_raw(json.dumps({"id": req_id, "ok": True, "result": result},
                                      ensure_ascii=False) + "\n")
        except Exception as e:
            log.exception("Command %s failed", cmd)
            self.send_raw(json.dumps({"id": req_id, "ok": False, "error": str(e)}) + "\n")


class IpcServer(socketserver.ThreadingMixIn, socketserver.UnixStreamServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, sock_path: Path,
                 handlers: dict[str, Callable[[dict], object]],
                 snapshot_fn: Callable[[], dict]):
        if sock_path.exists():
            try:
                os.unlink(sock_path)
            except OSError:
                pass
        super().__init__(str(sock_path), ClientHandler)
        self.handlers = handlers
        self.broadcaster = Broadcaster()
        self._snapshot_fn = snapshot_fn
        os.chmod(sock_path, 0o600)

    def send_snapshot(self, client: ClientHandler):
        data = self._snapshot_fn()
        client.send_raw(json.dumps({"event": "snapshot", "data": data}, ensure_ascii=False) + "\n")

    def serve_forever_in_thread(self) -> threading.Thread:
        t = threading.Thread(target=self.serve_forever, daemon=True)
        t.start()
        return t