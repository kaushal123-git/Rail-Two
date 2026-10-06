from typing import Optional
from app.models.station import Station
from app.repositories.fare_repository import FareRepository
from app.repositories.station_repository import haversine_distance_km
from app.schemas.fare import FareBreakdown


class FareService:
    def __init__(self, fare_repo: FareRepository):
        self.fare_repo = fare_repo

    async def calculate_fare(
        self,
        origin: Station,
        destination: Station,
        journey_type: str = "SINGLE",
        ticket_class: str = "SECOND",
        passenger_count: int = 1,
        duration: Optional[str] = "SINGLE",
    ) -> FareBreakdown:
        distance_km = haversine_distance_km(
            origin.latitude, origin.longitude, destination.latitude, destination.longitude
        )

        j_type = journey_type.upper()
        t_class = ticket_class.upper()

        rule = await self.fare_repo.get_applicable_rule(
            journey_type=j_type,
            ticket_class=t_class,
            distance_km=distance_km,
            origin_zone=origin.zone,
            destination_zone=destination.zone,
        )

        if rule is not None:
            unit_base = rule.base_fare + (distance_km * rule.per_km_rate)
            version = rule.version
            discount_pct = rule.discount_percentage
            tax_pct = rule.tax_percentage
        else:
            # Standard Mumbai Suburban Railway slab fallback
            version = "mumbai_suburban_v2026_default"
            discount_pct = 0.0
            tax_pct = 0.0

            if distance_km <= 10.0:
                base = 5.0
            elif distance_km <= 20.0:
                base = 10.0
            elif distance_km <= 35.0:
                base = 15.0
            elif distance_km <= 50.0:
                base = 20.0
            elif distance_km <= 70.0:
                base = 25.0
            else:
                base = 30.0

            if j_type == "SEASON":
                # Monthly season pass fallback base
                monthly_base = max(100.0, base * 15.0)
                if t_class == "FIRST":
                    unit_base = max(345.0, monthly_base * 3.5)
                elif t_class == "AC":
                    unit_base = max(650.0, monthly_base * 6.5)
                else:
                    unit_base = monthly_base
            else:
                if t_class == "FIRST":
                    unit_base = max(50.0, base * 7.0)
                elif t_class == "AC":
                    unit_base = max(650.0 if j_type == "SEASON" else 65.0, base * 9.0)
                else:
                    unit_base = base

                if j_type == "RETURN":
                    unit_base *= 2.0

        # Apply duration multiplier for Season passes
        if j_type == "SEASON" and duration:
            dur = duration.upper().replace(" ", "_")
            if dur in ("QUARTERLY", "3_MONTHS"):
                unit_base *= 2.7
            elif dur in ("HALF_YEARLY", "6_MONTHS"):
                unit_base *= 5.4
            elif dur in ("YEARLY", "12_MONTHS"):
                unit_base *= 10.8
            elif dur in ("FORTNIGHTLY", "15_DAYS"):
                unit_base *= 0.6

        subtotal = round(unit_base * passenger_count, 2)
        discount = round(subtotal * (discount_pct / 100.0), 2)
        tax = round((subtotal - discount) * (tax_pct / 100.0), 2)
        total_fare = max(5.0, round(subtotal - discount + tax, 2))

        return FareBreakdown(
            base_fare=round(unit_base, 2),
            distance_km=round(distance_km, 2),
            discount=discount,
            tax=tax,
            total_fare=total_fare,
            currency="INR",
            fare_rule_version=version,
        )
