from typing import Dict, Any, Optional, List
from app.schemas.assist import AssistChatResponse, AssistActionPayload


class AssistComposer:
    """
    Composes natural, human-friendly explanations alongside structured
    rich media cards (ROUTE_CARD, STATION_CARD, TICKET_CARD, JOURNEY_CARD, etc.)
    derived strictly from verified tool outputs.
    """

    @staticmethod
    def compose(
        request_id: str,
        intent: str,
        tool_name: Optional[str],
        tool_result: Optional[Dict[str, Any]],
        error: Optional[str] = None,
        status: str = "SUCCESS",
    ) -> AssistChatResponse:
        # 1. Error / Rejection / Timeout
        if status in ["ERROR", "REJECTED", "TIMEOUT"] or error:
            msg_text = error or "I was unable to verify this request with the railway engine."
            requires_auth = "sign in" in msg_text.lower() or "unauthorized" in msg_text.lower()
            return AssistChatResponse(
                request_id=request_id,
                text=msg_text,
                intent=intent,
                tool_name=tool_name,
                card_type="ERROR_CARD" if status == "ERROR" else "TEXT",
                card_data={"error": msg_text, "status": status},
                quick_replies=["🎫 How to Book", "🚆 Plan Route", "🛡️ Journey Guardian"],
                requires_auth=requires_auth,
            )

        # 2. General Help Fallback
        if intent == "GENERAL_HELP" or not tool_result:
            return AssistChatResponse(
                request_id=request_id,
                text=(
                    "Hello! I am LOCO Assist, your Mumbai Suburban Railway assistant.\n\n"
                    "I can look up live railway routes, calculate verified suburban fares, "
                    "check your digital tickets, monitor your live journey, and explain ticketing policies."
                ),
                intent=intent,
                tool_name=None,
                card_type="TEXT",
                quick_replies=[
                    "🚆 Route from Dadar to Borivali",
                    "🎫 Show my latest ticket",
                    "💰 Fare from Churchgate to Andheri",
                    "🛡️ Journey Guardian Status",
                ],
            )

        # 3. Route Search Tool Result -> ROUTE_CARD
        if tool_name == "get_route":
            desc = tool_result.get("description")
            text = (
                f"🚆 Verified Suburban Route:\n"
                f"• {tool_result['origin']} → {tool_result['destination']}\n"
                f"• Estimated Travel Time: ~{tool_result['duration_minutes']} min\n"
                f"• Transfers: {tool_result['transfers']} interchange(s)\n"
                f"• Standard Fare: ₹{tool_result['fare_inr']:.0f}"
            )
            return AssistChatResponse(
                request_id=request_id,
                text=text,
                intent=intent,
                tool_name=tool_name,
                card_type="ROUTE_CARD",
                card_data=tool_result,
                quick_replies=["Book This Route", "Alternative Routes", "Check Return Fare"],
                action_payload=AssistActionPayload(
                    action_type="PLAN_JOURNEY",
                    label=f"🚆 Plan Route: {tool_result['origin']} → {tool_result['destination']}",
                    target_screen="ROUTES",
                    parameters={
                        "origin": tool_result["origin"],
                        "destination": tool_result["destination"],
                        "route_id": str(tool_result.get("route_id", "")),
                    },
                ),
            )

        # 4. Route Options
        if tool_name == "get_route_options":
            opts = tool_result.get("options", [])
            lines = [f"Found {len(opts)} route option(s) between {tool_result['origin']} and {tool_result['destination']}:"]
            for i, opt in enumerate(opts, 1):
                lines.append(f"{i}. Duration: ~{opt['duration_minutes']} min | Transfers: {opt['transfers']} | Fare: ₹{opt['fare_inr']:.0f}")
            return AssistChatResponse(
                request_id=request_id,
                text="\n".join(lines),
                intent=intent,
                tool_name=tool_name,
                card_type="ROUTE_CARD",
                card_data=tool_result,
                quick_replies=["Book Fastest Route", "Check Fares"],
                action_payload=AssistActionPayload(
                    action_type="PLAN_JOURNEY",
                    label="🚆 Select Route Options",
                    target_screen="ROUTES",
                    parameters={
                        "origin": tool_result["origin"],
                        "destination": tool_result["destination"],
                    },
                ),
            )

        # 5. Fare Calculation
        if tool_name == "get_fare":
            text = (
                f"💰 Verified Suburban Railway Fare:\n"
                f"• Route: {tool_result['origin']} → {tool_result['destination']}\n"
                f"• Class: {tool_result['class_type']} Class ({tool_result['journey_type']})\n"
                f"• Total Fare: ₹{tool_result['total_fare']:.0f} (Distance: {tool_result['distance_km']} km)"
            )
            return AssistChatResponse(
                request_id=request_id,
                text=text,
                intent=intent,
                tool_name=tool_name,
                card_type="ROUTE_CARD",
                card_data=tool_result,
                quick_replies=["Book Ticket Now", "First Class Fare", "AC Local Fare"],
                action_payload=AssistActionPayload(
                    action_type="BOOK_TICKET",
                    label=f"🎫 Book Ticket (₹{tool_result['total_fare']:.0f})",
                    target_screen="HOME",
                    parameters={
                        "origin": tool_result["origin"],
                        "destination": tool_result["destination"],
                        "fare": str(tool_result["total_fare"]),
                    },
                ),
            )

        # 6. Station Details -> STATION_CARD
        if tool_name == "get_station_details":
            lines_str = ", ".join(tool_result.get("lines", []))
            facilities_str = "\n• ".join(tool_result.get("facilities", [])[:4])
            text = (
                f"🚉 Station Overview: {tool_result['name']} ({tool_result['code']})\n"
                f"• Railway Lines: {lines_str}\n"
                f"• Interchange: {'Yes (Major Suburban Hub)' if tool_result.get('is_interchange') else 'Standard Station'}\n"
                f"• Key Facilities:\n• {facilities_str}"
            )
            return AssistChatResponse(
                request_id=request_id,
                text=text,
                intent=intent,
                tool_name=tool_name,
                card_type="STATION_CARD",
                card_data=tool_result,
                quick_replies=["Nearby Stations", "Routes from here", "Book Ticket"],
                action_payload=AssistActionPayload(
                    action_type="EXPLORE_MAP",
                    label=f"🗺️ View {tool_result['name']} on Rail Map",
                    target_screen="MAP",
                    parameters={"station_id": tool_result["id"]},
                ),
            )

        # 7. Nearby Stations
        if tool_name == "get_nearby_stations":
            sts = tool_result.get("stations", [])
            lines = [tool_result.get("message", "Nearby railway stations:")]
            for s in sts:
                lines.append(f"• {s['name']} ({s['code']}) — {s['distance_text']}")
            return AssistChatResponse(
                request_id=request_id,
                text="\n".join(lines),
                intent=intent,
                tool_name=tool_name,
                card_type="STATION_CARD",
                card_data=tool_result,
                quick_replies=[f"Route from {sts[0]['name']}" if sts else "Plan Route", "Station Details"],
            )

        # 8. Ticket Details & Status -> TICKET_CARD
        if tool_name in ["get_ticket", "get_ticket_status", "check_ticket_validity"]:
            status_text = tool_result.get("status", "ACTIVE")
            mins_left = tool_result.get("minutes_remaining", 0)
            text = (
                f"🎫 Digital Transit Ticket #{tool_result.get('ticket_id', '')[:8].upper()}:\n"
                f"• Journey: {tool_result.get('origin', '')} → {tool_result.get('destination', '')}\n"
                f"• Current Status: {status_text}\n"
                f"• Validity: {'Valid for ' + str(mins_left) + ' min' if mins_left > 0 else 'Active offline QR'}"
            )
            return AssistChatResponse(
                request_id=request_id,
                text=text,
                intent=intent,
                tool_name=tool_name,
                card_type="TICKET_CARD",
                card_data=tool_result,
                quick_replies=["View My Tickets", "Journey Guardian", "Cancel Ticket"],
                action_payload=AssistActionPayload(
                    action_type="VIEW_TICKET",
                    label="🎫 Open Ticket & Show QR",
                    target_screen="TICKETS",
                    parameters={"ticket_id": tool_result.get("ticket_id", "")},
                ),
            )

        # 9. Ticket History
        if tool_name == "get_ticket_history":
            tickets = tool_result.get("tickets", [])
            if not tickets:
                text = "You do not have any active or recent tickets in your LOCO account."
                card_type = "TEXT"
                card_data = None
            else:
                lines = [f"Your recent digital tickets:"]
                for t in tickets:
                    lines.append(f"• #{t['ticket_id'][:8].upper()} | {t['origin']} → {t['destination']} | {t['status']} (₹{t['fare']:.0f})")
                text = "\n".join(lines)
                card_type = "TICKET_CARD"
                card_data = tickets[0]  # Show most recent as card

            return AssistChatResponse(
                request_id=request_id,
                text=text,
                intent=intent,
                tool_name=tool_name,
                card_type=card_type,
                card_data=card_data,
                quick_replies=["Book New Ticket", "Check Journey Status"],
                action_payload=AssistActionPayload(
                    action_type="VIEW_TICKET",
                    label="🎫 View All Tickets",
                    target_screen="TICKETS",
                ) if tickets else None,
            )

        # 10. Prepare Cancel Ticket -> CONFIRMATION_CARD
        if tool_name == "prepare_cancel_ticket":
            return AssistChatResponse(
                request_id=request_id,
                text=tool_result["message"],
                intent=intent,
                tool_name=tool_name,
                card_type="CONFIRMATION_CARD",
                card_data=tool_result,
                quick_replies=["Cancel Ticket", "Keep Ticket"],
                action_payload=AssistActionPayload(
                    action_type="CONFIRM_ACTION",
                    label="⚠️ Confirm Ticket Cancellation",
                    parameters={
                        "action_id": tool_result["action_id"],
                        "confirmation_token": tool_result["confirmation_token"],
                    },
                ),
            )

        # 11. Journey Guardian Status -> JOURNEY_CARD
        if tool_name in ["get_journey_status", "get_current_station", "get_destination"]:
            if tool_result.get("has_active_journey"):
                text = (
                    f"🛡️ Journey Guardian Active:\n"
                    f"• Trip: {tool_result['origin']} → {tool_result['destination']}\n"
                    f"• Current Station: {tool_result['current_station']}\n"
                    f"• Journey State: {tool_result['status']}\n"
                    f"• Security Status: {tool_result['security_state']}"
                )
                card_type = "JOURNEY_CARD"
            else:
                text = tool_result.get("message", "No active journey currently in progress.")
                card_type = "TEXT"

            return AssistChatResponse(
                request_id=request_id,
                text=text,
                intent=intent,
                tool_name=tool_name,
                card_type=card_type,
                card_data=tool_result,
                quick_replies=["Start Journey", "Show My Ticket", "Line Status"],
                action_payload=AssistActionPayload(
                    action_type="ACTIVATE_GUARDIAN",
                    label="🛡️ Open Journey Guardian",
                    target_screen="HOME",
                ),
            )

        # 12. Security Status
        if tool_name == "get_security_status":
            return AssistChatResponse(
                request_id=request_id,
                text=f"🛡️ Account & Journey Security:\n• Status: {tool_result['security_status']}\n• Details: {tool_result['message']}",
                intent=intent,
                tool_name=tool_name,
                card_type="TEXT",
                quick_replies=["Journey Guardian", "View Tickets", "UTS Rules"],
            )

        # 13. Service Alerts -> ALERT_CARD
        if tool_name in ["get_service_alerts", "get_live_route_status"]:
            alerts = tool_result.get("alerts", [])
            lines_status = tool_result.get("lines", [])

            if alerts:
                lines = ["🚨 Operational Bulletins:"]
                for a in alerts:
                    lines.append(f"• [{a['severity']}] {a['title']}: {a['description']}")
                text = "\n".join(lines)
            elif lines_status:
                lines = ["🚆 Mumbai Suburban Live Line Status:"]
                for l in lines_status:
                    lines.append(f"• {l['line_name']} ({l['line_code']}): {l['status']}")
                text = "\n".join(lines)
            else:
                text = tool_result.get("message", "All Mumbai suburban lines operating normally.")

            return AssistChatResponse(
                request_id=request_id,
                text=text,
                intent=intent,
                tool_name=tool_name,
                card_type="ALERT_CARD",
                card_data=tool_result,
                quick_replies=["Plan Route", "Station Details"],
            )

        # 14. App Help
        if tool_name == "get_app_help":
            return AssistChatResponse(
                request_id=request_id,
                text=f"📋 {tool_result['title']}:\n\n{tool_result['content']}",
                intent=intent,
                tool_name=tool_name,
                card_type="TEXT",
                card_data=tool_result,
                quick_replies=tool_result.get("quick_replies", ["How to Book", "UTS Rules"]),
                action_payload=AssistActionPayload(
                    action_type="BOOK_TICKET",
                    label="🎫 Book Ticket Now",
                    target_screen="HOME",
                ) if tool_result.get("topic") == "booking" else None,
            )

        # Fallback default
        return AssistChatResponse(
            request_id=request_id,
            text=str(tool_result),
            intent=intent,
            tool_name=tool_name,
            card_type="TEXT",
            card_data=tool_result,
            quick_replies=["Plan Route", "How to Book"],
        )
