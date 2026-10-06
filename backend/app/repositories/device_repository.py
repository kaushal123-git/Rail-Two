from typing import Optional, List
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from app.models.device import Device


class DeviceRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, device_id: str) -> Optional[Device]:
        result = await self.db.execute(select(Device).where(Device.id == device_id))
        return result.scalar_one_or_none()

    async def get_user_device(self, user_id: str, device_identifier: str) -> Optional[Device]:
        result = await self.db.execute(
            select(Device).where(
                Device.user_id == user_id,
                Device.device_identifier == device_identifier,
                Device.revoked_at.is_(None),
            )
        )
        return result.scalar_one_or_none()

    async def list_by_user(self, user_id: str) -> List[Device]:
        result = await self.db.execute(
            select(Device).where(Device.user_id == user_id, Device.revoked_at.is_(None))
        )
        return list(result.scalars().all())

    async def register_or_update(
        self,
        user_id: str,
        device_identifier: str,
        platform: str = "android",
        app_version: Optional[str] = None,
        os_version: Optional[str] = None,
        public_key: Optional[str] = None,
    ) -> Device:
        device = await self.get_user_device(user_id, device_identifier)
        now = datetime.now(timezone.utc)
        if device:
            device.last_seen_at = now
            if platform:
                device.platform = platform
            if app_version:
                device.app_version = app_version
            if os_version:
                device.os_version = os_version
            if public_key:
                device.public_key = public_key
        else:
            device = Device(
                user_id=user_id,
                device_identifier=device_identifier,
                platform=platform,
                app_version=app_version,
                os_version=os_version,
                public_key=public_key,
                last_seen_at=now,
            )
            self.db.add(device)

        await self.db.flush()
        await self.db.refresh(device)
        return device

    async def revoke(self, device_id: str, user_id: str) -> bool:
        device = await self.get_by_id(device_id)
        if not device or device.user_id != user_id:
            return False
        device.revoked_at = datetime.now(timezone.utc)
        await self.db.flush()
        return True
