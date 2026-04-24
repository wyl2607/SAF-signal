from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.db.base import Base
from app.models.sqlite_models import PriceCache
from app.services.cache import PriceCacheService


def test_price_cache_get_handles_sqlite_naive_datetimes(tmp_path):
    engine = create_engine(f"sqlite:///{tmp_path/'cache.sqlite3'}", future=True)
    Base.metadata.create_all(bind=engine)
    SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)

    with SessionLocal() as db:
        PriceCacheService.set_cache(db, "iea_cov_de", {"stock_days": 21}, ttl_hours=24)

    with SessionLocal() as db:
        stored = db.query(PriceCache).filter(PriceCache.market_type == "iea_cov_de").one()
        assert stored.expires_at.tzinfo is None

        cache = PriceCacheService.get_cache(db, "iea_cov_de")

    assert cache is not None
    assert cache.cached_data == {"stock_days": 21}


def test_price_cache_get_rejects_expired_naive_datetime(tmp_path):
    engine = create_engine(f"sqlite:///{tmp_path/'cache.sqlite3'}", future=True)
    Base.metadata.create_all(bind=engine)
    SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)

    with SessionLocal() as db:
        db.add(
            PriceCache(
                market_type="iea_cov_fr",
                cached_data={"stock_days": 19},
                expires_at=datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(hours=1),
            )
        )
        db.commit()

        cache = PriceCacheService.get_cache(db, "iea_cov_fr")

    assert cache is None
