from __future__ import annotations

from datetime import datetime, timezone
from types import SimpleNamespace

from app.schemas.sqlite_schemas import (
    MarketAlertRead,
    MarketPriceRead,
    PriceCacheRead,
    UserScenarioRead,
)


def test_sqlite_read_schemas_validate_from_attributes():
    now = datetime.now(timezone.utc)

    market_price = MarketPriceRead.model_validate(
        SimpleNamespace(
            id="price-1",
            market_type="ARA",
            price=1.23,
            unit="USD/L",
            source="test",
            timestamp=now,
            created_at=now,
        )
    )
    scenario = UserScenarioRead.model_validate(
        SimpleNamespace(
            id="scenario-1",
            user_id="user-1",
            scenario_name="Base case",
            description=None,
            parameters={"reserve_weeks": 3},
            created_at=now,
            updated_at=now,
        )
    )
    alert = MarketAlertRead.model_validate(
        SimpleNamespace(
            id="alert-1",
            market_type="EU_ETS",
            threshold_type="above",
            threshold_value=100.0,
            status="active",
            last_triggered=None,
            created_at=now,
            updated_at=now,
        )
    )
    cache = PriceCacheRead.model_validate(
        SimpleNamespace(
            market_type="iea_cov_DE",
            cached_data={"stock_days": 21},
            last_updated=now,
            expires_at=now,
        )
    )

    assert market_price.id == "price-1"
    assert scenario.parameters["reserve_weeks"] == 3
    assert alert.threshold_value == 100.0
    assert cache.cached_data["stock_days"] == 21
