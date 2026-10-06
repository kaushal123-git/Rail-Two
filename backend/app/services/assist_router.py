import re
import asyncio
from typing import Optional, Dict, Any, List, Tuple
from app.core.logging import logger
from app.schemas.assist import AssistContext
from app.services.assist_tools import AssistToolRegistry, AssistToolError


MUMBAI_STATIONS_CATALOG = [
    "Churchgate", "Marine Lines", "Charni Road", "Grant Road", "Mumbai Central",
    "Mahalaxmi", "Lower Parel", "Prabhadevi", "Dadar", "Matunga Road",
    "Mahim", "Bandra", "Khar Road", "Santacruz", "Vile Parle", "Andheri",
    "Jogeshwari", "Ram Mandir", "Goregaon", "Malad", "Kandivali", "Borivali",
    "Dahisar", "Mira Road", "Bhayandar", "Naigaon", "Vasai Road", "Nallasopara", "Virar",
    "CSMT", "Masjid", "Sandhurst Road", "Byculla", "Chinchpokli", "Currey Road",
    "Parel", "Sion", "Kurla", "Vidyavihar", "Ghatkopar", "Vikhroli", "Kanjurmarg",
    "Bhandup", "Nahur", "Mulund", "Thane", "Kalwa", "Mumbra", "Diva", "Dombivli", "Thakurli", "Kalyan",
    "Wadala Road", "GTB Nagar", "Chunabhatti", "Chembur", "Govandi", "Mankhurd",
    "Vashi", "Sanpada", "Juinagar", "Nerul", "Seawoods-Darave", "Belapur", "Kharghar", "Panvel"
]


class AssistRouter:
    """
    Intelligent router translating user language and application context
    into strict, verified tool executions.
    """

    def __init__(self, registry: AssistToolRegistry):
        self.registry = registry

    def check_adversarial(self, query: str) -> Optional[str]:
        """Detect prompt injection and adversarial attacks."""
        lower = query.lower()

        patterns = [
            r"ignore\s+(all\s+)?(previous\s+)?instructions",
            r"disregard\s+(the\s+)?system",
            r"show\s+(me\s+)?another\s+user",
            r"someone\s+else('s)?\s+ticket",
            r"other\s+user('s)?\s+ticket",
            r"fraud\s+(score|threshold|weight|model|formula)",
            r"tell\s+me\s+your\s+internal\s+threshold",
            r"bypass\s+(auth|security|verification|payment)",
            r"book\s+(without|zero|free)\s+payment",
            r"pretend\s+(the\s+)?ticket\s+is\s+valid",
            r"make\s+up\s+(the\s+)?(train|route|fare)",
            r"grant\s+admin",
            r"drop\s+table",
            r"select\s+\*\s+from",
        ]

        for p in patterns:
            if re.search(p, lower):
                return "I am LOCO Assist. I only operate within verified railway schedules, your authorized tickets, and official guidelines. System instructions, privacy controls, and security policies cannot be overridden."

        return None

    def extract_entities(self, query: str) -> Dict[str, Any]:
        """Extract stations, route preferences, lines, classes from natural text."""
        lower = query.lower().strip()

        # Find mentioned stations
        found_stations = []
        for s in MUMBAI_STATIONS_CATALOG:
            # Match word boundary
            pattern = r"\b" + re.escape(s.lower()) + r"\b"
            if re.search(pattern, lower):
                found_stations.append(s)

        origin = None
        destination = None

        # Check regex "from X to Y" or "X to Y" or "X se Y"
        from_to_match = re.search(r"from\s+([a-zA-Z\s]+?)\s+to\s+([a-zA-Z\s]+)", lower)
        se_match = re.search(r"([a-zA-Z\s]+?)\s+se\s+([a-zA-Z\s]+)", lower)

        if from_to_match:
            cand_from = from_to_match.group(1).strip()
            cand_to = from_to_match.group(2).strip()
            for s in found_stations:
                if s.lower() in cand_from:
                    origin = s
                elif s.lower() in cand_to:
                    destination = s
        elif se_match:
            cand_from = se_match.group(1).strip()
            cand_to = se_match.group(2).strip()
            for s in found_stations:
                if s.lower() in cand_from:
                    origin = s
                elif s.lower() in cand_to:
                    destination = s

        if not origin and not destination:
            if len(found_stations) >= 2:
                origin = found_stations[0]
                destination = found_stations[1]
            elif len(found_stations) == 1:
                origin = found_stations[0]

        # Preferences
        preference = "FASTEST"
        if "fewest transfer" in lower or "direct" in lower or "no change" in lower or "simplest" in lower or "easy" in lower:
            preference = "FEWEST_TRANSFERS"
        elif "cheap" in lower or "low fare" in lower or "least cost" in lower:
            preference = "CHEAPEST"
        elif "accessible" in lower or "wheelchair" in lower or "ramp" in lower:
            preference = "ACCESSIBLE"

        # Ticket class
        ticket_class = "SECOND"
        if "ac" in lower or "air condition" in lower:
            ticket_class = "AC"
        elif "first" in lower or "1st" in lower:
            ticket_class = "FIRST"

        # Line mentions
        line = None
        if "western" in lower or "wr" in lower:
            line = "Western"
        elif "central" in lower or "cr" in lower:
            line = "Central"
        elif "harbour" in lower or "hr" in lower:
            line = "Harbour"

        # UUID ticket ID match
        uuid_match = re.search(r"\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b", lower)
        ticket_id = uuid_match.group(0) if uuid_match else None

        return {
            "origin": origin,
            "destination": destination,
            "stations": found_stations,
            "preference": preference,
            "ticket_class": ticket_class,
            "line": line,
            "ticket_id": ticket_id,
        }

    async def route_and_execute(
        self,
        query: str,
        context: Optional[AssistContext] = None,
        current_user_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Classifies intent, selects approved tool, executes with timeout,
        and returns structured result.
        """
        # 1. Adversarial Injection Check
        adv_msg = self.check_adversarial(query)
        if adv_msg:
            return {
                "intent": "ADVERSARIAL_REJECTED",
                "tool_name": None,
                "tool_result": None,
                "error": adv_msg,
                "status": "REJECTED",
            }

        entities = self.extract_entities(query)
        lower = query.lower().strip()

        # Context overrides
        if not entities["ticket_id"] and context and context.current_ticket_id:
            entities["ticket_id"] = context.current_ticket_id

        # 2. Intent Classification & Tool Execution
        intent = "UNKNOWN"
        tool_name = None
        tool_coro = None

        # Route / Navigation
        if (
            ("how do i reach" in lower or "how to get" in lower or "route" in lower or "reach" in lower or "travel" in lower or "train from" in lower)
            and entities["origin"] and entities["destination"]
        ):
            intent = "ROUTE_SEARCH"
            tool_name = "get_route"
            tool_coro = self.registry.get_route(
                origin_query=entities["origin"],
                destination_query=entities["destination"],
                preference=entities["preference"],
            )

        elif (
            ("option" in lower or "alternative" in lower or "choices" in lower)
            and entities["origin"] and entities["destination"]
        ):
            intent = "ROUTE_OPTIONS"
            tool_name = "get_route_options"
            tool_coro = self.registry.get_route_options(
                origin_query=entities["origin"],
                destination_query=entities["destination"],
            )

        # Fare Query
        elif "fare" in lower or "cost" in lower or "how much" in lower or "price" in lower or "rate" in lower:
            if entities["origin"] and entities["destination"]:
                intent = "FARE_QUERY"
                tool_name = "get_fare"
                tool_coro = self.registry.get_fare(
                    origin_query=entities["origin"],
                    destination_query=entities["destination"],
                    ticket_class=entities["ticket_class"],
                )
            else:
                intent = "APP_HELP"
                tool_name = "get_app_help"
                tool_coro = self.registry.get_app_help("booking")

        # Ticket Cancellation
        elif "cancel" in lower and ("ticket" in lower or "booking" in lower or "my" in lower):
            intent = "TICKET_CANCEL"
            tool_name = "prepare_cancel_ticket"
            target_tid = entities["ticket_id"]
            if not target_tid and current_user_id:
                # Find most recent ticket for the user
                recent = await self.registry.get_ticket_history(current_user_id, limit=1)
                if recent.get("tickets"):
                    target_tid = recent["tickets"][0]["ticket_id"]

            if target_tid:
                tool_coro = self.registry.prepare_cancel_ticket(target_tid, current_user_id)
            else:
                intent = "APP_HELP"
                tool_name = "get_app_help"
                tool_coro = self.registry.get_app_help("cancellation")

        # Ticket Queries
        elif "ticket" in lower or "pass" in lower or "qr" in lower:
            if "valid" in lower or "expire" in lower or "how long" in lower:
                intent = "TICKET_VALIDITY"
                tool_name = "check_ticket_validity"
                target_tid = entities["ticket_id"]
                if not target_tid and current_user_id:
                    recent = await self.registry.get_ticket_history(current_user_id, limit=1)
                    if recent.get("tickets"):
                        target_tid = recent["tickets"][0]["ticket_id"]
                if target_tid:
                    tool_coro = self.registry.check_ticket_validity(target_tid, current_user_id)
                else:
                    intent = "TICKET_HISTORY"
                    tool_name = "get_ticket_history"
                    tool_coro = self.registry.get_ticket_history(current_user_id, limit=3)
            elif "my ticket" in lower or "show ticket" in lower or "latest ticket" in lower or "active ticket" in lower:
                intent = "TICKET_HISTORY"
                tool_name = "get_ticket_history"
                tool_coro = self.registry.get_ticket_history(current_user_id, limit=3)
            elif entities["ticket_id"]:
                intent = "TICKET_DETAILS"
                tool_name = "get_ticket"
                tool_coro = self.registry.get_ticket(entities["ticket_id"], current_user_id)
            elif "history" in lower or "all tickets" in lower:
                intent = "TICKET_HISTORY"
                tool_name = "get_ticket_history"
                tool_coro = self.registry.get_ticket_history(current_user_id, limit=5)
            else:
                intent = "APP_HELP"
                tool_name = "get_app_help"
                tool_coro = self.registry.get_app_help("booking")

        # Journey / Location Assistance
        elif "where am i" in lower or "current station" in lower or "which station" in lower:
            intent = "CURRENT_STATION"
            tool_name = "get_current_station"
            lat = context.latitude if context else None
            lon = context.longitude if context else None
            tool_coro = self.registry.get_current_station(current_user_id, latitude=lat, longitude=lon)

        elif "destination" in lower or "where do i get off" in lower or "when should i get off" in lower:
            intent = "JOURNEY_DESTINATION"
            tool_name = "get_destination"
            tool_coro = self.registry.get_destination(current_user_id)

        elif "how does" in lower or "how to" in lower or "what is" in lower or "explain" in lower:
            intent = "APP_HELP"
            tool_name = "get_app_help"
            if "security" in lower or "restricted" in lower:
                intent = "SECURITY_STATUS"
                tool_name = "get_security_status"
                tool_coro = self.registry.get_security_status(current_user_id)
            elif "guardian" in lower or "safety" in lower or "sos" in lower:
                tool_coro = self.registry.get_app_help("journey_guardian")
            elif "cancel" in lower or "refund" in lower:
                tool_coro = self.registry.get_app_help("cancellation")
            elif "bio" in lower or "finger" in lower or "face" in lower:
                tool_coro = self.registry.get_app_help("biometrics")
            elif "offline" in lower or "internet" in lower:
                tool_coro = self.registry.get_app_help("offline_tickets")
            elif "location" in lower or "gps" in lower or "permission" in lower:
                tool_coro = self.registry.get_app_help("location_permission")
            elif "pass" in lower or "season" in lower or "uts" in lower:
                tool_coro = self.registry.get_app_help("season_pass")
            else:
                tool_coro = self.registry.get_app_help("booking")

        elif "status of my trip" in lower or "my journey" in lower or "journey status" in lower or "guardian status" in lower or "how much longer" in lower:
            intent = "JOURNEY_STATUS"
            tool_name = "get_journey_status"
            tool_coro = self.registry.get_journey_status(current_user_id)

        # Service / Disruption Alerts
        elif "delay" in lower or "disrupt" in lower or "alert" in lower or "block" in lower or "mega block" in lower or "issue" in lower:
            intent = "SERVICE_ALERT"
            tool_name = "get_service_alerts"
            tool_coro = self.registry.get_service_alerts(line=entities["line"])

        # Live Line Status
        elif "line status" in lower or "status of" in lower:
            intent = "LIVE_ROUTE_STATUS"
            tool_name = "get_live_route_status"
            tool_coro = self.registry.get_live_route_status(line=entities["line"])

        # Station Information & POI
        elif ("station" in lower or "facility" in lower or "platform" in lower or "wheelchair" in lower or "atvm" in lower) and entities["origin"]:
            intent = "STATION_DETAILS"
            tool_name = "get_station_details"
            tool_coro = self.registry.get_station_details(entities["origin"])

        elif "near me" in lower or "nearby" in lower or "closest station" in lower:
            intent = "NEARBY_STATIONS"
            tool_name = "get_nearby_stations"
            lat = context.latitude if context and context.latitude else 19.0178  # Dadar default if mock
            lon = context.longitude if context and context.longitude else 72.8478
            tool_coro = self.registry.get_nearby_stations(latitude=lat, longitude=lon)

        # Security Status
        elif "security" in lower or "restricted" in lower or "challenge" in lower or "why location" in lower:
            if "why location" in lower or "permission" in lower:
                intent = "APP_HELP"
                tool_name = "get_app_help"
                tool_coro = self.registry.get_app_help("location_permission")
            else:
                intent = "SECURITY_STATUS"
                tool_name = "get_security_status"
                tool_coro = self.registry.get_security_status(current_user_id)

        # App Help Topics
        elif "how to book" in lower or "buy ticket" in lower:
            intent = "APP_HELP"
            tool_name = "get_app_help"
            tool_coro = self.registry.get_app_help("booking")
        elif "biometric" in lower or "fingerprint" in lower:
            intent = "APP_HELP"
            tool_name = "get_app_help"
            tool_coro = self.registry.get_app_help("biometrics")
        elif "offline" in lower or "no internet" in lower:
            intent = "APP_HELP"
            tool_name = "get_app_help"
            tool_coro = self.registry.get_app_help("offline_tickets")
        elif "season pass" in lower or "monthly pass" in lower or "uts" in lower:
            intent = "APP_HELP"
            tool_name = "get_app_help"
            tool_coro = self.registry.get_app_help("season_pass")

        # Two stations mentioned without explicit command -> route search
        elif entities["origin"] and entities["destination"]:
            intent = "ROUTE_SEARCH"
            tool_name = "get_route"
            tool_coro = self.registry.get_route(
                origin_query=entities["origin"],
                destination_query=entities["destination"],
                preference=entities["preference"],
            )

        # Single station mentioned -> station search/details
        elif entities["origin"] and len(found := entities["stations"]) == 1:
            intent = "STATION_DETAILS"
            tool_name = "get_station_details"
            tool_coro = self.registry.get_station_details(entities["origin"])

        # Fallback / General Help
        if not tool_coro:
            intent = "GENERAL_HELP"
            return {
                "intent": intent,
                "tool_name": None,
                "tool_result": None,
                "error": None,
                "status": "SUCCESS",
            }

        # 3. Tool Execution with 5.0-second Timeout
        try:
            tool_result = await asyncio.wait_for(tool_coro, timeout=5.0)
            return {
                "intent": intent,
                "tool_name": tool_name,
                "tool_result": tool_result,
                "error": None,
                "status": "SUCCESS",
            }
        except asyncio.TimeoutError:
            logger.error("Assist tool %s timed out after 5.0 seconds", tool_name)
            return {
                "intent": intent,
                "tool_name": tool_name,
                "tool_result": None,
                "error": "I couldn't verify this railway information in time. Please try again.",
                "status": "TIMEOUT",
            }
        except AssistToolError as ate:
            return {
                "intent": intent,
                "tool_name": tool_name,
                "tool_result": None,
                "error": ate.message,
                "error_code": ate.code,
                "status": "ERROR",
            }
        except Exception as e:
            logger.exception("Unexpected error executing assist tool %s: %s", tool_name, str(e))
            return {
                "intent": intent,
                "tool_name": tool_name,
                "tool_result": None,
                "error": "An unexpected error occurred while looking up verified information.",
                "status": "ERROR",
            }
