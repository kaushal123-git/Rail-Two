from typing import Optional
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from app.models.session import Session


class SessionRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create(
        self,
        user_id: str,
        refresh_token_hash: str,
        expires_at: datetime,
        device_id: Optional[str] = None,
        ip_hash: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> Session:
        session = Session(
            user_id=user_id,
            device_id=device_id,
            refresh_token_hash=refresh_token_hash,
            expires_at=expires_at,
            ip_hash=ip_hash,
            user_agent=user_agent,
            last_used_at=datetime.now(timezone.utc),
        )
        self.db.add(session)
        await self.db.flush()
        await self.db.refresh(session)
        return session

    async def get_active_by_token_hash(self, token_hash: str) -> Optional[Session]:
        now = datetime.now(timezone.utc)
        result = await self.db.execute(
            select(Session).where(
                Session.refresh_token_hash == token_hash,
                Session.revoked_at.is_(None),
                Session.expires_at > now,
            )
        )
        return result.scalar_one_or_none()

    async def revoke_session(self, session_id: str) -> bool:
        session = await self.db.get(Session, session_id)
        if session:
            session.revoked_at = datetime.now(timezone.utc)
            await self.db.flush()
            return True
        return False

    async def revoke_all_user_sessions(self, user_id: str) -> int:
        now = datetime.now(timezone.utc)
        stmt = (
            update(Session)
            .where(Session.user_id == user_id, Session.revoked_at.is_(None))
            .values(revoked_at=now)
        )
        result = await self.db.execute(stmt)
        await self.db.flush()
        return result.rowcount

    async def touch(self, session_id: str) -> None:
        session = await self.db.get(Session, session_id)
        if session:
            session.last_used_at = datetime.now(timezone.utc)
            await self.db.flush()

    async def get_by_id(self, session_id: str) -> Optional[Session]:
        return await self.db.get(Session, session_id)

    async def get_user_sessions(self, user_id: str):
        result = await self.db.execute(
            select(Session).where(Session.user_id == user_id).order_by(Session.created_at.desc())
        )
        return list(result.scalars().all())
