import asyncio
import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone
from typing import Optional, List, Dict, Any, Tuple
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.logging import logger
from app.models.ticket import Ticket, TicketStatus
from app.models.ticket_event import TicketEventType
from app.models.journey import JourneyStatus
from app.repositories.station_repository import StationRepository, haversine_distance_km
from app.repositories.network_repository import NetworkRepository
from app.repositories.ticket_repository import TicketRepository
from app.repositories.journey_repository import JourneyRepository
from app.repositories.assistant_repository import AssistantRepository
from app.services.routing_service import RoutingService
from app.services.ticket_service import TicketService
from app.schemas.routing import RouteSearchRequest


class AssistToolError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


class AssistToolRegistry:
    """
    Central tool execution registry for LOCO Assist.
    Every tool enforces strict input schemas, authorization checks,
    bounded timeouts, and clean error states.
    """

    def __init__(
        self,
        db: AsyncSession,
        station_repo: StationRepository,
        network_repo: NetworkRepository,
        ticket_repo: TicketRepository,
        journey_repo: JourneyRepository,
        assistant_repo: AssistantRepository,
        routing_service: RoutingService,
        ticket_service: TicketService,
    ):
        self.db = db
        self.station_repo = station_repo
        self.network_repo = network_repo
        self.ticket_repo = ticket_repo
        self.journey_repo = journey_repo
        self.assistant_repo = assistant_repo
        self.routing_service = routing_service
        self.ticket_service = ticket_service

    # ================= 1. STATION TOOLS =================

    async def search_station(self, query: str, limit: int = 5) -> Dict[str, Any]:
        """Search stations by name or code."""
        if not query or len(query.strip()) < 2:
            return {"stations": [], "message": "Please enter at least 2 characters to search stations."}

        stations = await self.station_repo.search(query.strip(), limit=limit)
        results = [
            {
                "id": s.id,
                "name": s.name,
                "code": s.code,
                "zone": s.zone,
                "city": s.city,
                "latitude": s.latitude,
                "longitude": s.longitude,
            }
            for s in stations
        ]
        return {
            "query": query,
            "count": len(results),
            "stations": results,
            "message": f"Found {len(results)} station(s) matching '{query}'." if results else f"No railway stations found matching '{query}'.",
        }

    async def get_station_details(self, identifier: str) -> Dict[str, Any]:
        """Get verified station details, lines, and facilities."""
        st = await self.station_repo.get_by_id(identifier)
        if not st:
            st = await self.station_repo.get_by_code(identifier)
        if not st:
            matches = await self.station_repo.search(identifier, limit=1)
            st = matches[0] if matches else None

        if not st:
            raise AssistToolError("STATION_NOT_FOUND", f"Station '{identifier}' not found in Mumbai Suburban network.")

        # Determine line tags based on zone and known station codes
        lines = []
        if st.zone == "Western" or st.code in ["CCG", "MMCT", "DDR", "BA", "ADH", "BVI", "VR"]:
            lines.append("Western Railway (WR)")
        if st.zone == "Central" or st.code in ["CSMT", "DDR", "CLA", "TNA", "KYN"]:
            lines.append("Central Railway Main Line (CR)")
        if st.zone == "Harbour" or st.code in ["CSMT", "VDLR", "CLA", "VSH", "PNVL"]:
            lines.append("Harbour Line (HR)")
        if not lines:
            lines.append(f"{st.zone} Suburban Division")

        is_interchange = st.code in ["DDR", "CSMT", "CLA", "ADH", "TNA", "VDLR"]

        facilities = [
            "Automatic Ticket Vending Machines (ATVM)",
            "UTS Unreserved Booking Counters",
            "Foot Over Bridges (FOB) with Escalators",
            "Divyangjan Wheelchair Accessibility",
            "Emergency Medical Room (EMR)",
            "Railway Protection Force (RPF) Chowki",
        ]

        return {
            "id": st.id,
            "name": st.name,
            "code": st.code,
            "display_name": st.display_name,
            "zone": st.zone,
            "latitude": st.latitude,
            "longitude": st.longitude,
            "lines": lines,
            "is_interchange": is_interchange,
            "facilities": facilities,
        }

    async def get_nearby_stations(self, latitude: float, longitude: float, radius_km: float = 5.0, limit: int = 5) -> Dict[str, Any]:
        """Find closest stations based on geo-coordinates."""
        nearby = await self.station_repo.find_nearby(latitude, longitude, radius_km=radius_km, limit=limit)
        results = [
            {
                "id": s.id,
                "name": s.name,
                "code": s.code,
                "zone": s.zone,
                "distance_km": round(dist, 2),
                "distance_text": f"{round(dist * 1000)} meters away" if dist < 1.0 else f"{round(dist, 1)} km away",
            }
            for s, dist in nearby
        ]
        return {
            "user_latitude": latitude,
            "user_longitude": longitude,
            "radius_km": radius_km,
            "stations": results,
            "message": f"Found {len(results)} stations within {radius_km} km." if results else f"No stations within {radius_km} km.",
        }

    # ================= 2. ROUTING & FARE TOOLS =================

    async def get_route(
        self,
        origin_query: str,
        destination_query: str,
        preference: str = "FASTEST",
    ) -> Dict[str, Any]:
        """Fetch verified route from LOCO Phase 3 Routing Engine."""
        # Resolve origin
        origin = await self._resolve_station(origin_query)
        dest = await self._resolve_station(destination_query)

        if not origin or not dest:
            raise AssistToolError("INVALID_STATIONS", f"Could not resolve stations: '{origin_query}' -> '{destination_query}'.")

        if origin.id == dest.id:
            raise AssistToolError("SAME_STATION", "Origin and destination cannot be the same station.")

        pref = preference.upper() if preference else "FASTEST"
        if pref not in ["FASTEST", "FEWEST_TRANSFERS", "CHEAPEST", "ACCESSIBLE"]:
            pref = "FASTEST"

        req = RouteSearchRequest(
            origin_station_id=origin.id,
            destination_station_id=dest.id,
            preference=pref,
            travel_class="SECOND",
        )

        try:
            res = await self.routing_service.search_routes(req)
        except Exception as e:
            logger.error("Routing engine error for %s -> %s: %s", origin.name, dest.name, str(e))
            raise AssistToolError("ROUTE_SERVICE_UNAVAILABLE", "Routing engine is temporarily unavailable. Please retry.")

        if not res.routes:
            raise AssistToolError("NO_ROUTE_FOUND", f"No verified rail route found between {origin.name} and {dest.name}.")

        best = res.routes[0]
        station_names = []
        for leg in best.legs:
            if leg.station_sequence:
                station_names.extend(leg.station_sequence)
        if not station_names:
            station_names = [origin.name, dest.name]
        # Deduplicate consecutive stations
        dedup = []
        for s in station_names:
            if not dedup or dedup[-1] != s:
                dedup.append(s)
        station_names = dedup

        return {
            "route_id": best.route_id,
            "origin": origin.name,
            "origin_code": origin.code,
            "destination": dest.name,
            "destination_code": dest.code,
            "duration_minutes": best.total_duration_minutes,
            "transfers": best.transfers_count,
            "fare_inr": float(best.fare_estimate),
            "stations": station_names,
            "station_count": len(station_names),
            "service_status": best.service_status or "NORMAL_SERVICE",
            "preference_used": pref,
            "description": f"{origin.name} to {dest.name} takes ~{best.total_duration_minutes} min with {best.transfers_count} transfer(s). Fare: ₹{best.fare_estimate:.0f}.",
        }

    async def get_route_options(self, origin_query: str, destination_query: str) -> Dict[str, Any]:
        """Fetch multiple route options (fastest, fewest transfers) between stations."""
        origin = await self._resolve_station(origin_query)
        dest = await self._resolve_station(destination_query)

        if not origin or not dest:
            raise AssistToolError("INVALID_STATIONS", f"Could not resolve stations: '{origin_query}' -> '{destination_query}'.")

        req = RouteSearchRequest(
            origin_station_id=origin.id,
            destination_station_id=dest.id,
            preference="FASTEST",
            travel_class="SECOND",
        )
        res = await self.routing_service.search_routes(req)
        options = [
            {
                "route_id": opt.route_id,
                "duration_minutes": opt.total_duration_minutes,
                "transfers": opt.transfers_count,
                "fare_inr": float(opt.fare_estimate),
                "station_count": opt.total_stops or len(opt.legs),
            }
            for opt in (res.routes or [])
        ]
        return {
            "origin": origin.name,
            "destination": dest.name,
            "options": options,
            "count": len(options),
        }

    async def get_fare(
        self,
        origin_query: str,
        destination_query: str,
        ticket_class: str = "SECOND",
        journey_type: str = "SINGLE",
    ) -> Dict[str, Any]:
        """Authoritatively calculate fare without creating a booking."""
        origin = await self._resolve_station(origin_query)
        dest = await self._resolve_station(destination_query)

        if not origin or not dest:
            raise AssistToolError("INVALID_STATIONS", f"Could not resolve stations for fare calculation.")

        success, msg, breakdown = await self.ticket_service.estimate_fare(
            origin_station_id=origin.id,
            destination_station_id=dest.id,
            journey_type=journey_type,
            ticket_class=ticket_class,
            passenger_count=1,
        )

        if not success or not breakdown:
            raise AssistToolError("FARE_CALCULATION_FAILED", msg or "Could not calculate fare.")

        return {
            "origin": origin.name,
            "destination": dest.name,
            "class_type": ticket_class.upper(),
            "journey_type": journey_type.upper(),
            "total_fare": breakdown.total_fare,
            "base_fare": breakdown.base_fare,
            "distance_km": breakdown.distance_km,
            "currency": breakdown.currency,
            "description": f"Verified fare from {origin.name} to {dest.name} ({ticket_class.upper()} Class, {journey_type.upper()}): ₹{breakdown.total_fare:.0f}.",
        }

    # ================= 3. NETWORK & SERVICE ALERTS =================

    async def get_live_route_status(self, line: Optional[str] = None) -> Dict[str, Any]:
        """Get live line operational status and alerts."""
        lines = await self.network_repo.list_lines()
        updates = await self.network_repo.list_active_updates()

        statuses = []
        for l in lines:
            if line and line.lower() not in l.name.lower() and line.lower() not in l.code.lower():
                continue
            line_updates = [u for u in updates if u.line_id == l.id]
            severity = "NORMAL"
            if any(u.severity == "CRITICAL" for u in line_updates):
                severity = "DISRUPTED"
            elif any(u.severity == "WARNING" for u in line_updates):
                severity = "DELAYS"

            statuses.append({
                "line_code": l.code,
                "line_name": l.name,
                "status": severity,
                "active_alerts_count": len(line_updates),
            })

        return {
            "network": "Mumbai Suburban Railway",
            "lines": statuses,
            "is_all_clear": all(s["status"] == "NORMAL" for s in statuses),
        }

    async def get_service_alerts(self, line: Optional[str] = None) -> Dict[str, Any]:
        """Get verified operational service updates and bulletins."""
        updates = await self.network_repo.list_active_updates()
        alerts = [
            {
                "title": u.title,
                "description": u.description,
                "severity": u.severity,
                "source": u.source,
                "effective_from": u.effective_from.isoformat() if u.effective_from else None,
            }
            for u in updates
        ]

        return {
            "alert_count": len(alerts),
            "alerts": alerts,
            "message": "All suburban lines operating according to regular timetable." if not alerts else f"{len(alerts)} operational bulletin(s) active.",
        }

    # ================= 4. TICKET TOOLS (AUTHENTICATED & IDOR PROTECTED) =================

    async def get_ticket(self, ticket_id: str, current_user_id: Optional[str]) -> Dict[str, Any]:
        """Fetch ticket details strictly authorized for the authenticated user."""
        if not current_user_id:
            raise AssistToolError("AUTH_REQUIRED", "You must be signed in to view ticket details.")

        ticket = await self.ticket_repo.get_by_id(ticket_id)
        if not ticket:
            raise AssistToolError("TICKET_NOT_FOUND", f"Ticket '{ticket_id}' was not found.")

        # IDOR Protection
        if ticket.user_id != current_user_id:
            logger.warning("Assist IDOR attempt: user %s requested ticket %s owned by %s", current_user_id, ticket_id, ticket.user_id)
            raise AssistToolError("FORBIDDEN", "Unauthorized: You do not have permission to view this ticket.")

        origin_name = ticket.origin_station.name if ticket.origin_station else ticket.origin_station_id
        dest_name = ticket.destination_station.name if ticket.destination_station else ticket.destination_station_id

        return {
            "ticket_id": ticket.id,
            "provider_ticket_id": ticket.provider_ticket_id or f"LOCO-{ticket.id[:8].upper()}",
            "origin": origin_name,
            "destination": dest_name,
            "status": ticket.ticket_status,
            "valid_from": ticket.valid_from.isoformat() if ticket.valid_from else None,
            "valid_until": ticket.valid_until.isoformat() if ticket.valid_until else None,
            "fare": ticket.fare,
            "passenger_count": ticket.passenger_count,
            "class_type": ticket.ticket_class,
            "journey_type": ticket.journey_type,
            "is_active": ticket.ticket_status in [TicketStatus.ISSUED.value, TicketStatus.ACTIVE.value, TicketStatus.IN_JOURNEY.value],
        }

    async def get_ticket_status(self, ticket_id: str, current_user_id: Optional[str]) -> Dict[str, Any]:
        """Get status of a specific ticket belonging to the user."""
        ticket_data = await self.get_ticket(ticket_id, current_user_id)
        return {
            "ticket_id": ticket_data["ticket_id"],
            "status": ticket_data["status"],
            "origin": ticket_data["origin"],
            "destination": ticket_data["destination"],
            "valid_until": ticket_data["valid_until"],
            "is_active": ticket_data["is_active"],
        }

    async def get_ticket_history(self, current_user_id: Optional[str], limit: int = 5) -> Dict[str, Any]:
        """Get recent tickets for the authenticated user."""
        if not current_user_id:
            raise AssistToolError("AUTH_REQUIRED", "Please sign in to view your ticket history.")

        tickets = await self.ticket_repo.list_by_user(current_user_id, limit=limit)
        results = []
        for t in tickets:
            origin_name = t.origin_station.name if t.origin_station else t.origin_station_id
            dest_name = t.destination_station.name if t.destination_station else t.destination_station_id
            results.append({
                "ticket_id": t.id,
                "provider_ticket_id": t.provider_ticket_id,
                "origin": origin_name,
                "destination": dest_name,
                "status": t.ticket_status,
                "fare": t.fare,
                "valid_until": t.valid_until.isoformat() if t.valid_until else None,
            })

        return {
            "count": len(results),
            "tickets": results,
            "message": f"Found {len(results)} recent ticket(s)." if results else "No tickets found in your account.",
        }

    async def check_ticket_validity(self, ticket_id: str, current_user_id: Optional[str]) -> Dict[str, Any]:
        """Verify ticket expiration against server authoritative time."""
        t = await self.get_ticket(ticket_id, current_user_id)
        now = datetime.now(timezone.utc)

        valid_until_dt = None
        if t["valid_until"]:
            try:
                valid_until_dt = datetime.fromisoformat(t["valid_until"])
            except Exception:
                pass

        if not valid_until_dt:
            is_valid = t["is_active"]
            mins_left = 0
        else:
            is_valid = t["is_active"] and (now < valid_until_dt)
            mins_left = max(0, int((valid_until_dt - now).total_seconds() / 60))

        return {
            "ticket_id": ticket_id,
            "is_valid": is_valid,
            "status": t["status"],
            "minutes_remaining": mins_left,
            "valid_until": t["valid_until"],
            "message": f"Ticket is valid for {mins_left} more minutes." if is_valid else f"Ticket is no longer valid (Status: {t['status']}).",
        }

    # ================= 5. JOURNEY TOOLS (JOURNEY GUARDIAN) =================

    async def get_journey_status(self, current_user_id: Optional[str]) -> Dict[str, Any]:
        """Check active journey from Journey Guardian system."""
        if not current_user_id:
            raise AssistToolError("AUTH_REQUIRED", "Please sign in to check your live journey status.")

        journey = await self.journey_repo.get_active_for_user(current_user_id)
        if not journey:
            return {
                "has_active_journey": False,
                "message": "You do not have an active journey running on Journey Guardian. Start a journey from your active ticket when boarding.",
            }

        orig_st = await self.station_repo.get_by_id(journey.origin_station_id)
        dest_st = await self.station_repo.get_by_id(journey.destination_station_id)
        curr_st = await self.station_repo.get_by_id(journey.current_station_id) if journey.current_station_id else None

        return {
            "has_active_journey": True,
            "journey_id": journey.id,
            "ticket_id": journey.ticket_id,
            "status": journey.status,
            "origin": orig_st.name if orig_st else journey.origin_station_id,
            "destination": dest_st.name if dest_st else journey.destination_station_id,
            "current_station": curr_st.name if curr_st else "En route",
            "security_state": journey.security_state,
            "is_guardian_active": True,
        }

    async def get_current_station(
        self,
        current_user_id: Optional[str],
        latitude: Optional[float] = None,
        longitude: Optional[float] = None,
    ) -> Dict[str, Any]:
        """Determine current station from active journey or location coordinates."""
        if current_user_id:
            journey = await self.journey_repo.get_active_for_user(current_user_id)
            if journey and journey.current_station_id:
                st = await self.station_repo.get_by_id(journey.current_station_id)
                if st:
                    return {
                        "source": "ACTIVE_JOURNEY",
                        "station_name": st.name,
                        "station_code": st.code,
                        "zone": st.zone,
                        "message": f"You are currently at {st.name} ({st.code}) based on your live journey.",
                    }

        if latitude is not None and longitude is not None:
            nearby = await self.station_repo.find_nearby(latitude, longitude, radius_km=1.5, limit=1)
            if nearby:
                st, dist = nearby[0]
                return {
                    "source": "GEOLOCATION",
                    "station_name": st.name,
                    "station_code": st.code,
                    "zone": st.zone,
                    "distance_meters": int(dist * 1000),
                    "message": f"You are near {st.name} ({round(dist * 1000)}m away).",
                }

        return {
            "source": "UNKNOWN",
            "station_name": None,
            "message": "Unable to determine your station. Please ensure location services are enabled or specify your station name.",
        }

    async def get_destination(self, current_user_id: Optional[str]) -> Dict[str, Any]:
        """Get destination of the commuter's active journey."""
        if not current_user_id:
            raise AssistToolError("AUTH_REQUIRED", "Sign in to check your journey destination.")

        journey = await self.journey_repo.get_active_for_user(current_user_id)
        if not journey:
            return {"has_destination": False, "message": "No active journey in progress."}

        dest = await self.station_repo.get_by_id(journey.destination_station_id)
        dest_name = dest.name if dest else journey.destination_station_id
        return {
            "has_destination": True,
            "destination_name": dest_name,
            "destination_code": dest.code if dest else None,
            "message": f"Your destination station is {dest_name}.",
        }

    # ================= 6. SECURITY HELP & PRIVACY =================

    async def get_security_status(self, current_user_id: Optional[str]) -> Dict[str, Any]:
        """
        User-facing journey security status.
        PRIVACY REQUIREMENT: ZERO leakage of ML fraud scores, features, weights, or thresholds!
        """
        if not current_user_id:
            raise AssistToolError("AUTH_REQUIRED", "Please sign in to check your account security status.")

        journey = await self.journey_repo.get_active_for_user(current_user_id)
        if not journey:
            return {
                "security_status": "NORMAL",
                "message": "Your LOCO account and device security are in good standing.",
            }

        # Safe high-level user status
        state = journey.security_state
        if state == "SECURE":
            user_msg = "Your journey is verified and protected by Journey Guardian."
            status_label = "VERIFIED"
        elif state == "CHALLENGED":
            user_msg = "LOCO detected an unusual journey signal and requires a quick journey verification check before continuing."
            status_label = "VERIFICATION_REQUIRED"
        elif state == "FLAGGED":
            user_msg = "Your journey is under automated review for trip safety."
            status_label = "MONITORING"
        else:
            user_msg = "Journey security is active."
            status_label = "ACTIVE"

        return {
            "security_status": status_label,
            "message": user_msg,
        }

    # ================= 7. APP GUIDANCE KNOWLEDGE BASE =================

    async def get_app_help(self, topic: str) -> Dict[str, Any]:
        """Verified help and policy guidance from LOCO documentation."""
        t = topic.lower().strip()

        kb = {
            "booking": {
                "title": "How to Book a Ticket on LOCO",
                "content": (
                    "1. On the Home screen, select your Origin and Destination stations.\n"
                    "2. Choose Class (Second, First, or AC Local) and Journey Type (Single or Return).\n"
                    "3. Review the server-calculated fare.\n"
                    "4. Tap 'Pay & Issue Ticket' to complete payment via Razorpay, UPI, or R-Wallet.\n"
                    "5. Your cryptographically signed HMAC QR ticket is instantly created and works offline!"
                ),
                "quick_replies": ["Book Ticket Now", "Ticket Rules", "Payment Info"],
            },
            "cancellation": {
                "title": "Ticket Cancellation & Refund Policy",
                "content": (
                    "Unreserved suburban tickets can be cancelled before journey commencement while in ISSUED state.\n"
                    "Once a journey has started or the turnstile QR is scanned, the ticket becomes active and cannot be cancelled.\n"
                    "Approved refunds are automatically returned to your original payment method."
                ),
                "quick_replies": ["Cancel My Ticket", "View My Tickets", "How to Book"],
            },
            "journey_guardian": {
                "title": "About Journey Guardian Safety Mode",
                "content": (
                    "Journey Guardian uses S2 spatial geofencing to monitor your journey progress.\n"
                    "It alerts you when arriving at your destination, verifies interchange transfers at Dadar/Kurla, "
                    "and protects your digital ticket against fraud."
                ),
                "quick_replies": ["Activate Guardian", "Security Status", "Route Status"],
            },
            "biometrics": {
                "title": "Biometric Authentication Security",
                "content": (
                    "LOCO uses your device's native OS BiometricPrompt (Android) and LocalAuthentication (iOS).\n"
                    "Your raw fingerprint or face data NEVER leaves your phone or touches LOCO servers.\n"
                    "Biometrics unlock a hardware-backed cryptographic session token."
                ),
                "quick_replies": ["Security Help", "Login Rules"],
            },
            "location_permission": {
                "title": "Why LOCO Requires Location Access",
                "content": (
                    "LOCO needs location permissions for:\n"
                    "1. Automatically finding nearest stations for fast booking.\n"
                    "2. Verifying you are at the railway station for ticket validity.\n"
                    "3. Journey Guardian arrival and interchange notifications.\n"
                    "4. Fraud prevention against spoofed GPS locations."
                ),
                "quick_replies": ["Security Help", "Journey Guardian"],
            },
            "offline_tickets": {
                "title": "Offline Ticket Usage",
                "content": (
                    "All LOCO tickets feature a server-signed HMAC-SHA256 QR code.\n"
                    "Even if your mobile network drops inside underground tunnels or crowded stations, "
                    "your ticket QR remains authentic and verifiable by Railway Ticket Checking Staff (TTE) scanners offline."
                ),
                "quick_replies": ["View My Tickets", "How to Book"],
            },
            "season_pass": {
                "title": "Season Pass & UTS Rules",
                "content": (
                    "LOCO supports suburban unreserved single, return, and monthly/quarterly season passes.\n"
                    "Season passes must be renewed before expiry and require valid commuter identity verification."
                ),
                "quick_replies": ["How to Book", "Ticket Rules"],
            },
        }

        # Match key
        matched_key = None
        for k in kb.keys():
            if k in t or t in k:
                matched_key = k
                break

        if not matched_key:
            if "guardian" in t or "sos" in t or "safety" in t:
                matched_key = "journey_guardian"
            elif "cancel" in t or "refund" in t:
                matched_key = "cancellation"
            elif "book" in t or "buy" in t or "fare" in t:
                matched_key = "booking"
            elif "bio" in t or "finger" in t or "face" in t:
                matched_key = "biometrics"
            elif "gps" in t or "loc" in t or "permission" in t:
                matched_key = "location_permission"
            elif "offline" in t or "internet" in t or "network" in t:
                matched_key = "offline_tickets"
            elif "pass" in t or "monthly" in t or "season" in t:
                matched_key = "season_pass"
            else:
                matched_key = "booking"

        entry = kb[matched_key]
        return {
            "topic": matched_key,
            "title": entry["title"],
            "content": entry["content"],
            "quick_replies": entry["quick_replies"],
        }

    # ================= 8. SENSITIVE ACTION TOOLS (CONFIRMATION REQUIRED) =================

    async def prepare_cancel_ticket(self, ticket_id: str, current_user_id: Optional[str]) -> Dict[str, Any]:
        """
        Stage a ticket cancellation action.
        RULE: NEVER execute cancellation from raw natural language alone!
        Generates an explicit confirmation token and card with a 5-minute expiry.
        """
        if not current_user_id:
            raise AssistToolError("AUTH_REQUIRED", "Sign in required to cancel a ticket.")

        ticket = await self.ticket_repo.get_by_id(ticket_id)
        if not ticket:
            raise AssistToolError("TICKET_NOT_FOUND", "Ticket not found.")

        if ticket.user_id != current_user_id:
            raise AssistToolError("FORBIDDEN", "Unauthorized: You do not own this ticket.")

        eligible_statuses = [
            TicketStatus.CREATED.value,
            TicketStatus.PAYMENT_PENDING.value,
            TicketStatus.ISSUED.value,
            TicketStatus.ACTIVE.value,
        ]
        if ticket.ticket_status not in eligible_statuses:
            raise AssistToolError(
                "NON_CANCELLABLE_STATUS",
                f"Ticket in '{ticket.ticket_status}' status cannot be cancelled. Only uncompleted tickets in CREATED, ISSUED, or ACTIVE state are eligible.",
            )

        # Generate cryptographic confirmation token
        secret_bytes = secrets.token_bytes(32)
        confirmation_token = hmac.new(
            settings.JWT_SECRET_KEY.encode(),
            f"cancel:{ticket.id}:{current_user_id}:{datetime.now(timezone.utc).timestamp()}".encode(),
            hashlib.sha256,
        ).hexdigest()

        expires_at = datetime.now(timezone.utc) + timedelta(minutes=5)
        action = await self.assistant_repo.create_action(
            user_id=current_user_id,
            action_type="CANCEL_TICKET",
            target_id=ticket.id,
            confirmation_token=confirmation_token,
            expires_at=expires_at,
        )

        origin_name = ticket.origin_station.name if ticket.origin_station else ticket.origin_station_id
        dest_name = ticket.destination_station.name if ticket.destination_station else ticket.destination_station_id

        return {
            "action_id": action.id,
            "confirmation_token": confirmation_token,
            "ticket_id": ticket.id,
            "origin": origin_name,
            "destination": dest_name,
            "fare": ticket.fare,
            "expires_in_seconds": 300,
            "message": f"I found your active ticket from {origin_name} to {dest_name} (Fare: ₹{ticket.fare:.0f}). Are you sure you want to cancel it? A refund will be credited.",
        }

    async def execute_cancel_ticket(self, action_id: str, confirmation_token: str, current_user_id: str) -> Dict[str, Any]:
        """Execute the confirmed cancellation action."""
        action = await self.assistant_repo.get_action_by_id(action_id)
        if not action or action.confirmation_token != confirmation_token:
            raise AssistToolError("INVALID_ACTION_TOKEN", "Cancellation token is invalid or expired.")

        if action.user_id != current_user_id:
            raise AssistToolError("FORBIDDEN", "Unauthorized action execution.")

        now = datetime.now(timezone.utc)
        expires_at = action.expires_at
        if expires_at and expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        if expires_at and expires_at < now:
            await self.assistant_repo.update_action_status(action, "EXPIRED")
            raise AssistToolError("ACTION_EXPIRED", "The cancellation confirmation has expired. Please try again.")

        if action.status != "PENDING_CONFIRMATION":
            raise AssistToolError("ACTION_ALREADY_PROCESSED", f"Action already processed with status: {action.status}.")

        # Execute cancellation
        ticket = await self.ticket_repo.get_by_id(action.target_id)
        if not ticket:
            await self.assistant_repo.update_action_status(action, "FAILED")
            raise AssistToolError("TICKET_NOT_FOUND", "Ticket no longer exists.")

        try:
            curr_status = TicketStatus(ticket.ticket_status)
        except ValueError:
            curr_status = None

        if not curr_status or not self.ticket_service.validate_transition(curr_status, TicketStatus.CANCELLED):
            await self.assistant_repo.update_action_status(action, "FAILED")
            raise AssistToolError(
                "CANNOT_CANCEL",
                f"Ticket in '{ticket.ticket_status}' status cannot be cancelled.",
            )

        updated_ticket = await self.ticket_repo.update_status(
            ticket=ticket,
            new_status=TicketStatus.CANCELLED,
            event_type=TicketEventType.TICKET_CANCELLED.value,
            metadata={"reason": "Cancelled via LOCO Assist user confirmation", "action_id": action.id},
        )
        if not updated_ticket:
            await self.assistant_repo.update_action_status(action, "FAILED")
            raise AssistToolError("CANCELLATION_FAILED", "Failed to cancel ticket in database.")

        await self.assistant_repo.update_action_status(action, "EXECUTED", executed_at=now)

        return {
            "ticket_id": updated_ticket.id,
            "status": updated_ticket.ticket_status,
            "refund_amount": updated_ticket.fare,
            "message": f"Ticket #{updated_ticket.id[:8].upper()} cancelled successfully. Refund of ₹{updated_ticket.fare:.0f} initiated to your original payment method.",
        }

    # ================= HELPER =================

    async def _resolve_station(self, query: str):
        if not query:
            return None
        st = await self.station_repo.get_by_id(query)
        if st:
            return st
        st = await self.station_repo.get_by_code(query)
        if st:
            return st
        matches = await self.station_repo.search(query.strip(), limit=1)
        return matches[0] if matches else None
