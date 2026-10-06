from datetime import datetime, timezone
from typing import Optional, List
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.assistant import AssistantRequest, AssistantAction


class AssistantRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def create_request_log(
        self,
        request_id: str,
        query: str,
        intent: str,
        tool_name: Optional[str] = None,
        tool_arguments_hash: Optional[str] = None,
        result_status: str = "SUCCESS",
        user_id: Optional[str] = None,
        session_id: Optional[str] = None,
        error_code: Optional[str] = None,
    ) -> AssistantRequest:
        log_entry = AssistantRequest(
            request_id=request_id,
            query=query,
            intent=intent,
            tool_name=tool_name,
            tool_arguments_hash=tool_arguments_hash,
            result_status=result_status,
            user_id=user_id,
            session_id=session_id,
            error_code=error_code,
        )
        self.session.add(log_entry)
        await self.session.commit()
        await self.session.refresh(log_entry)
        return log_entry

    async def create_action(
        self,
        user_id: str,
        action_type: str,
        target_id: str,
        confirmation_token: str,
        expires_at: datetime,
    ) -> AssistantAction:
        action = AssistantAction(
            user_id=user_id,
            action_type=action_type,
            target_id=target_id,
            confirmation_token=confirmation_token,
            status="PENDING_CONFIRMATION",
            expires_at=expires_at,
        )
        self.session.add(action)
        await self.session.commit()
        await self.session.refresh(action)
        return action

    async def get_action_by_token(self, token: str) -> Optional[AssistantAction]:
        stmt = select(AssistantAction).where(AssistantAction.confirmation_token == token)
        res = await self.session.execute(stmt)
        return res.scalar_one_or_none()

    async def get_action_by_id(self, action_id: str) -> Optional[AssistantAction]:
        stmt = select(AssistantAction).where(AssistantAction.id == action_id)
        res = await self.session.execute(stmt)
        return res.scalar_one_or_none()

    async def update_action_status(
        self,
        action: AssistantAction,
        status: str,
        executed_at: Optional[datetime] = None,
    ) -> AssistantAction:
        action.status = status
        if executed_at:
            action.executed_at = executed_at
        await self.session.commit()
        await self.session.refresh(action)
        return action
