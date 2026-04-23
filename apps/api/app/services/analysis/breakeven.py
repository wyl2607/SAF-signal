from app.schemas.analysis import BreakevenStatus, TippingPointAssessment
from app.services.analysis.pathway_costs import (
    EUR_TO_USD,
    FOSSIL_JET_EMISSIONS_KG_PER_L,
    carbon_credit_usd_per_l,
    effective_saf_cost,
    get_pathway_cost,
)


def _status_for_spread(spread_pct: float) -> BreakevenStatus:
    if spread_pct > 25:
        return "uneconomic"
    if spread_pct > 5:
        return "inflection"
    if spread_pct >= -10:
        return "marginal_switch"
    return "dominant"


def compute_tipping_point(
    fossil_jet_usd_per_l: float,
    carbon_price_eur_per_t: float,
    subsidy_usd_per_l: float,
    blend_rate_pct: float,
    pathway_key: str = "hefa",
) -> TippingPointAssessment:
    pathway = get_pathway_cost(pathway_key)
    carbon_credit = carbon_credit_usd_per_l(carbon_price_eur_per_t, pathway.carbon_reduction_pct)
    effective_support = (subsidy_usd_per_l + carbon_credit) * (blend_rate_pct / 100.0)
    net_saf_cost = effective_saf_cost(
        pathway_key,
        carbon_price_eur_per_t=carbon_price_eur_per_t,
        subsidy_usd_per_l=subsidy_usd_per_l,
        blend_rate_pct=blend_rate_pct,
    )
    spread_usd_per_l = net_saf_cost - fossil_jet_usd_per_l
    spread_pct = (spread_usd_per_l / fossil_jet_usd_per_l) * 100.0
    return TippingPointAssessment(
        pathway=pathway,
        fossil_jet_usd_per_l=fossil_jet_usd_per_l,
        carbon_price_eur_per_t=carbon_price_eur_per_t,
        subsidy_usd_per_l=subsidy_usd_per_l,
        blend_rate_pct=blend_rate_pct,
        carbon_credit_usd_per_l=carbon_credit,
        effective_support_usd_per_l=effective_support,
        net_saf_cost_usd_per_l=net_saf_cost,
        net_cost_spread_usd_per_l=spread_usd_per_l,
        spread_pct=spread_pct,
        status=_status_for_spread(spread_pct),
    )


def compute_breakeven_oil_price(
    *,
    saf_effective_usd_per_l: float,
    jet_proxy_slope: float,
    jet_proxy_intercept: float,
) -> float:
    if jet_proxy_slope <= 0:
        raise ValueError("jet_proxy_slope must be > 0")
    return max(0.0, (saf_effective_usd_per_l - jet_proxy_intercept) / jet_proxy_slope)
