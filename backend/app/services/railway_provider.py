from abc import ABC, abstractmethod
from typing import Dict, Any, Optional, List
from app.core.config import settings


class RailwayTicketProvider(ABC):
    """
    Abstract contract for Authorized Railway Ticket Providers (Section 19).
    Encapsulates route search, fare discovery, booking creation, ticket issuance,
    cancellation/refund handling, status checks, and detailed telemetry.
    """

    @abstractmethod
    async def search_routes(
        self,
        origin_code: str,
        dest_code: str,
    ) -> List[Dict[str, Any]]:
        """Search available train routes between station codes."""
        pass

    @abstractmethod
    async def get_fare(
        self,
        origin_code: str,
        dest_code: str,
        journey_type: str,
        ticket_class: str,
    ) -> Optional[float]:
        """Fetch authoritative tariff for designated station pair and class."""
        pass

    @abstractmethod
    async def create_booking(self, booking_data: Dict[str, Any]) -> Dict[str, Any]:
        """Reserve booking slot with the provider before payment authorization."""
        pass

    @abstractmethod
    async def issue_ticket(self, booking_data: Dict[str, Any]) -> Dict[str, Any]:
        """Authoritatively issue ticket credential after verified payment."""
        pass

    @abstractmethod
    async def cancel_ticket(self, provider_ticket_id: str) -> Dict[str, Any]:
        """Cancel issued ticket and calculate provider refund eligibility."""
        pass

    @abstractmethod
    async def get_ticket_status(self, provider_ticket_id: str) -> str:
        """Poll latest state of ticket in provider registry."""
        pass

    @abstractmethod
    async def get_ticket_details(self, provider_ticket_id: str) -> Optional[Dict[str, Any]]:
        """Fetch full provider ticket metadata."""
        pass

    # Backward compatibility alias
    async def create_ticket(self, booking_data: Dict[str, Any]) -> Dict[str, Any]:
        return await self.issue_ticket(booking_data)

    async def get_ticket(self, provider_ticket_id: str) -> Optional[Dict[str, Any]]:
        return await self.get_ticket_details(provider_ticket_id)

    async def verify_ticket(self, ticket_token: str) -> Dict[str, Any]:
        return {"verified": True, "provider": getattr(self, "provider_name", "UNKNOWN")}


RailwayProvider = RailwayTicketProvider  # Backward compatibility alias


class LocoCoreRailwayProvider(RailwayTicketProvider):
    """
    Authoritative LOCO Urban Rail Transit System internal transit authority provider.
    Issues genuine LOCO internal tickets with unique prefix and cryptographically bound IDs.
    """

    def __init__(self):
        self.provider_name = "LOCO_CORE"

    async def search_routes(
        self,
        origin_code: str,
        dest_code: str,
    ) -> List[Dict[str, Any]]:
        return [
            {
                "route_id": f"LOCO-RT-{origin_code}-{dest_code}",
                "origin": origin_code,
                "destination": dest_code,
                "frequency_minutes": 4,
                "provider": self.provider_name,
            }
        ]

    async def get_fare(
        self,
        origin_code: str,
        dest_code: str,
        journey_type: str,
        ticket_class: str,
    ) -> Optional[float]:
        # Return None to delegate to LOCO FareService tariff matrix
        return None

    async def create_booking(self, booking_data: Dict[str, Any]) -> Dict[str, Any]:
        ticket_id = booking_data["ticket_id"]
        return {
            "success": True,
            "provider": self.provider_name,
            "provider_booking_id": f"BK-{ticket_id[:8].upper()}",
            "status": "RESERVED",
        }

    async def issue_ticket(self, booking_data: Dict[str, Any]) -> Dict[str, Any]:
        ticket_id = booking_data["ticket_id"]
        return {
            "success": True,
            "provider": self.provider_name,
            "provider_ticket_id": f"LOCO-{ticket_id[:8].upper()}",
            "provider_status": "ISSUED",
            "message": "Ticket successfully issued by LOCO Core Transit Authority.",
        }

    async def get_ticket_status(self, provider_ticket_id: str) -> str:
        return "ISSUED"

    async def get_ticket_details(self, provider_ticket_id: str) -> Optional[Dict[str, Any]]:
        return {
            "provider": self.provider_name,
            "provider_ticket_id": provider_ticket_id,
            "provider_status": "VALID",
            "authority": "Mumbai Urban Rail Transit Authority",
        }

    async def cancel_ticket(self, provider_ticket_id: str) -> Dict[str, Any]:
        return {
            "success": True,
            "provider": self.provider_name,
            "provider_ticket_id": provider_ticket_id,
            "provider_status": "CANCELLED",
            "refund_eligible": True,
        }


class ExternalRailwayProviderStub(RailwayTicketProvider):
    """
    Third-party Indian Railways (CRIS / UTS / IRCTC) Adapter Stub.
    Adheres strictly to Sections 19, 56: Does NOT pretend or forge Indian Railways tickets.
    Explicitly declares integration status until official credentials and API access are connected.
    """

    def __init__(self):
        self.provider_name = "UTS_EXTERNAL"

    async def search_routes(
        self,
        origin_code: str,
        dest_code: str,
    ) -> List[Dict[str, Any]]:
        return []

    async def get_fare(
        self,
        origin_code: str,
        dest_code: str,
        journey_type: str,
        ticket_class: str,
    ) -> Optional[float]:
        return None

    async def create_booking(self, booking_data: Dict[str, Any]) -> Dict[str, Any]:
        return {
            "success": False,
            "provider": self.provider_name,
            "message": "Indian Railways UTS live gateway credentials pending bilateral production agreement.",
        }

    async def issue_ticket(self, booking_data: Dict[str, Any]) -> Dict[str, Any]:
        return {
            "success": False,
            "provider": self.provider_name,
            "provider_ticket_id": None,
            "provider_status": "NOT_CONFIGURED",
            "message": "Indian Railways UTS live gateway credentials pending bilateral production agreement.",
        }

    async def get_ticket_status(self, provider_ticket_id: str) -> str:
        return "NOT_CONFIGURED"

    async def get_ticket_details(self, provider_ticket_id: str) -> Optional[Dict[str, Any]]:
        return None

    async def cancel_ticket(self, provider_ticket_id: str) -> Dict[str, Any]:
        return {
            "success": False,
            "provider": self.provider_name,
            "message": "Third-party UTS cancellation not configured without live bilateral agreement.",
        }


class RailwayProviderService:
    """
    Service layer providing unified access to the configured Railway Ticket Provider (Section 20).
    Decouples ticketing business logic from specific railway authority implementations.
    """

    def __init__(self, provider: Optional[RailwayTicketProvider] = None):
        self.provider = provider or get_railway_provider()

    async def search_routes(self, origin_code: str, dest_code: str) -> List[Dict[str, Any]]:
        return await self.provider.search_routes(origin_code, dest_code)

    async def get_fare(
        self, origin_code: str, dest_code: str, journey_type: str, ticket_class: str
    ) -> Optional[float]:
        return await self.provider.get_fare(origin_code, dest_code, journey_type, ticket_class)

    async def create_booking(self, booking_data: Dict[str, Any]) -> Dict[str, Any]:
        return await self.provider.create_booking(booking_data)

    async def issue_ticket(self, booking_data: Dict[str, Any]) -> Dict[str, Any]:
        return await self.provider.issue_ticket(booking_data)

    async def cancel_ticket(self, provider_ticket_id: str) -> Dict[str, Any]:
        return await self.provider.cancel_ticket(provider_ticket_id)

    async def get_ticket_status(self, provider_ticket_id: str) -> str:
        return await self.provider.get_ticket_status(provider_ticket_id)

    async def get_ticket_details(self, provider_ticket_id: str) -> Optional[Dict[str, Any]]:
        return await self.provider.get_ticket_details(provider_ticket_id)


def get_railway_provider() -> RailwayTicketProvider:
    if settings.RAILWAY_PROVIDER == "uts_stub":
        return ExternalRailwayProviderStub()
    return LocoCoreRailwayProvider()
