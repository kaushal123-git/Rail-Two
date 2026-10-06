from typing import Optional, List
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from app.models.user import User


class UserRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, user_id: str) -> Optional[User]:
        result = await self.db.execute(select(User).where(User.id == user_id))
        return result.scalar_one_or_none()

    async def get_by_phone(self, phone_number: str) -> Optional[User]:
        result = await self.db.execute(select(User).where(User.phone_number == phone_number))
        return result.scalar_one_or_none()

    async def get_by_email(self, email: str) -> Optional[User]:
        result = await self.db.execute(select(User).where(User.email == email))
        return result.scalar_one_or_none()

    async def create(
        self,
        phone_number: str,
        full_name: str = "Commuter",
        email: Optional[str] = None,
        phone_verified: bool = False,
    ) -> User:
        user = User(
            phone_number=phone_number,
            full_name=full_name,
            email=email,
            phone_verified=phone_verified,
        )
        self.db.add(user)
        await self.db.flush()
        await self.db.refresh(user)
        return user

    async def update_profile(
        self,
        user_id: str,
        full_name: Optional[str] = None,
        email: Optional[str] = None,
        profile_image_url: Optional[str] = None,
    ) -> Optional[User]:
        user = await self.get_by_id(user_id)
        if not user:
            return None
        if full_name is not None:
            user.full_name = full_name
        if email is not None:
            user.email = email
        if profile_image_url is not None:
            user.profile_image_url = profile_image_url
        await self.db.flush()
        await self.db.refresh(user)
        return user

    async def update_last_login(self, user_id: str) -> None:
        await self.db.execute(
            update(User)
            .where(User.id == user_id)
            .values(last_login_at=datetime.now(timezone.utc))
        )
        await self.db.flush()

    async def set_mpin(self, user_id: str, hashed_mpin: str) -> bool:
        user = await self.get_by_id(user_id)
        if not user:
            return False
        user.hashed_mpin = hashed_mpin
        await self.db.flush()
        return True

    async def mark_phone_verified(self, user_id: str) -> None:
        user = await self.get_by_id(user_id)
        if user:
            user.phone_verified = True
            await self.db.flush()
