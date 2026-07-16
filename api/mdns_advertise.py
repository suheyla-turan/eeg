"""
mDNS / Bonjour yayını — Flutter `eegserver.local` veya servis keşfi ile bulur.

Servis: eegserver._eeg-api._tcp.local.
Host:   eegserver.local.
"""

from __future__ import annotations

import socket
from typing import Optional

from zeroconf import IPVersion, ServiceInfo
from zeroconf.asyncio import AsyncZeroconf

SERVICE_TYPE = "_eeg-api._tcp.local."
INSTANCE_NAME = "eegserver"
SERVICE_NAME = f"{INSTANCE_NAME}.{SERVICE_TYPE}"
HOSTNAME = "eegserver.local."


def _local_ipv4() -> str:
    """Aynı ağdaki telefona duyurulacak LAN IP."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.connect(("8.8.8.8", 80))
        return sock.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        sock.close()


class MdnsAdvertiser:
    """Uvicorn / asyncio ile uyumlu async mDNS yayıncısı."""

    def __init__(self, port: int = 8000) -> None:
        self.port = port
        self._aiozc: Optional[AsyncZeroconf] = None
        self._info: Optional[ServiceInfo] = None

    async def start(self) -> None:
        if self._aiozc is not None:
            return

        ip = _local_ipv4()
        self._info = ServiceInfo(
            SERVICE_TYPE,
            SERVICE_NAME,
            addresses=[socket.inet_aton(ip)],
            port=self.port,
            properties={
                b"path": b"/live",
                b"api": b"eeg",
            },
            server=HOSTNAME,
        )
        self._aiozc = AsyncZeroconf(ip_version=IPVersion.V4Only)
        await self._aiozc.async_register_service(self._info)
        print(f"mDNS yayında: http://eegserver.local:{self.port}  ({ip})")
        print(f"  servis: {SERVICE_NAME}")

    async def stop(self) -> None:
        if self._aiozc is None:
            return
        try:
            if self._info is not None:
                await self._aiozc.async_unregister_service(self._info)
        finally:
            await self._aiozc.async_close()
            self._aiozc = None
            self._info = None
            print("mDNS yayını durduruldu.")
