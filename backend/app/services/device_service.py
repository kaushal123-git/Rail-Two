from typing import Optional, List
from app.models.device import Device
from app.repositories.device_repository import DeviceRepository


class DeviceService:
    def __init__(self, device_repo: DeviceRepository):
        self.repo = device_repo

    async def register_device(
        self,
        user_id: str,
        device_identifier: str,
        platform: str = "android",
        app_version: Optional[str] = None,
        os_version: Optional[str] = None,
        public_key: Optional[str] = None,
    ) -> Device:
        """Register or update device hardware information."""
        return await self.repo.register_or_update(
            user_id=user_id,
            device_identifier=device_identifier,
            platform=platform,
            app_version=app_version,
            os_version=os_version,
            public_key=public_key,
        )

    async def list_user_devices(self, user_id: str) -> List[Device]:
        """List all active registered devices for commuter."""
        return await self.repo.list_by_user(user_id)

    async def revoke_device(self, device_id: str, user_id: str) -> bool:
        """Revoke device authorization."""
        return await self.repo.revoke(device_id, user_id)

    async def verify_device_integrity(self, device_id: str, attestation_token: str) -> bool:
        """
        Prepared interface for future Android Play Integrity / Apple App Attest.
        Will verify attestation payload cryptographically with Google/Apple servers.
        """
        # Phase 1: Clean abstraction interface
        return True
