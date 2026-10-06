from typing import Optional, List
from datetime import datetime, timezone
from sqlalchemy import select, update, desc
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.fraud_model_version import FraudModelVersion
from app.models.fraud_prediction import FraudPrediction
from app.models.fraud_decision import FraudDecision
from app.models.fraud_feature_snapshot import FraudFeatureSnapshot
from app.models.fraud_rule_event import FraudRuleEvent


class FraudModelVersionRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_active(self) -> Optional[FraudModelVersion]:
        stmt = select(FraudModelVersion).where(FraudModelVersion.is_active.is_(True)).order_by(desc(FraudModelVersion.created_at)).limit(1)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_version(self, version: str) -> Optional[FraudModelVersion]:
        stmt = select(FraudModelVersion).where(FraudModelVersion.version == version)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def create(self, model_version: FraudModelVersion) -> FraudModelVersion:
        self.session.add(model_version)
        await self.session.flush()
        return model_version

    async def activate_version(self, version: str) -> bool:
        # Deactivate all first
        await self.session.execute(update(FraudModelVersion).values(is_active=False))
        # Activate specific version
        stmt = update(FraudModelVersion).where(FraudModelVersion.version == version).values(is_active=True)
        res = await self.session.execute(stmt)
        await self.session.flush()
        return res.rowcount > 0

    async def list_versions(self) -> List[FraudModelVersion]:
        stmt = select(FraudModelVersion).order_by(desc(FraudModelVersion.created_at))
        result = await self.session.execute(stmt)
        return list(result.scalars().all())


class FraudFeatureSnapshotRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def create(self, snapshot: FraudFeatureSnapshot) -> FraudFeatureSnapshot:
        self.session.add(snapshot)
        await self.session.flush()
        return snapshot

    async def get_by_id(self, snapshot_id: str) -> Optional[FraudFeatureSnapshot]:
        stmt = select(FraudFeatureSnapshot).where(FraudFeatureSnapshot.id == snapshot_id)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()


class FraudPredictionRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def create(self, prediction: FraudPrediction) -> FraudPrediction:
        self.session.add(prediction)
        await self.session.flush()
        return prediction

    async def get_by_id(self, prediction_id: str) -> Optional[FraudPrediction]:
        stmt = select(FraudPrediction).where(FraudPrediction.id == prediction_id)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_for_user(self, user_id: str, limit: int = 20) -> List[FraudPrediction]:
        stmt = (
            select(FraudPrediction)
            .where(FraudPrediction.user_id == user_id)
            .order_by(desc(FraudPrediction.created_at))
            .limit(limit)
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_for_ticket(self, ticket_id: str) -> List[FraudPrediction]:
        stmt = (
            select(FraudPrediction)
            .where(FraudPrediction.ticket_id == ticket_id)
            .order_by(desc(FraudPrediction.created_at))
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_for_journey(self, journey_id: str) -> List[FraudPrediction]:
        stmt = (
            select(FraudPrediction)
            .where(FraudPrediction.journey_id == journey_id)
            .order_by(desc(FraudPrediction.created_at))
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())


class FraudDecisionRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def create(self, decision: FraudDecision) -> FraudDecision:
        self.session.add(decision)
        await self.session.flush()
        return decision

    async def get_by_id(self, decision_id: str) -> Optional[FraudDecision]:
        stmt = select(FraudDecision).where(FraudDecision.id == decision_id)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_for_user(self, user_id: str, limit: int = 20) -> List[FraudDecision]:
        stmt = (
            select(FraudDecision)
            .where(FraudDecision.user_id == user_id)
            .order_by(desc(FraudDecision.created_at))
            .limit(limit)
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_for_ticket(self, ticket_id: str) -> List[FraudDecision]:
        stmt = (
            select(FraudDecision)
            .where(FraudDecision.ticket_id == ticket_id)
            .order_by(desc(FraudDecision.created_at))
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_for_journey(self, journey_id: str) -> List[FraudDecision]:
        stmt = (
            select(FraudDecision)
            .where(FraudDecision.journey_id == journey_id)
            .order_by(desc(FraudDecision.created_at))
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def create_rule_event(self, rule_event: FraudRuleEvent) -> FraudRuleEvent:
        self.session.add(rule_event)
        await self.session.flush()
        return rule_event
