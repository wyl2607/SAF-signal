from app.schemas.analysis import PathwayCostBand

EUR_TO_USD = 1.08
FOSSIL_JET_EMISSIONS_KG_PER_L = 2.5


PATHWAY_COSTS: dict[str, PathwayCostBand] = {
    "hefa": PathwayCostBand(
        pathway_key="hefa",
        name="HEFA",
        min_usd_per_l=1.0,
        max_usd_per_l=1.5,
        midpoint_usd_per_l=1.25,
        carbon_reduction_pct=70.0,
        maturity_level="commercial",
    ),
    "atj": PathwayCostBand(
        pathway_key="atj",
        name="ATJ",
        min_usd_per_l=1.3,
        max_usd_per_l=1.7,
        midpoint_usd_per_l=1.5,
        carbon_reduction_pct=65.0,
        maturity_level="early_commercial",
    ),
    "ft": PathwayCostBand(
        pathway_key="ft",
        name="Fischer-Tropsch",
        min_usd_per_l=1.5,
        max_usd_per_l=2.3,
        midpoint_usd_per_l=1.9,
        carbon_reduction_pct=80.0,
        maturity_level="scaling",
    ),
    "ptl": PathwayCostBand(
        pathway_key="ptl",
        name="Power-to-Liquid",
        min_usd_per_l=3.0,
        max_usd_per_l=5.0,
        midpoint_usd_per_l=4.0,
        carbon_reduction_pct=95.0,
        maturity_level="demonstration",
    ),
    "fossil_jet_crisis": PathwayCostBand(
        pathway_key="fossil_jet_crisis",
        name="Fossil Jet (Crisis Range)",
        min_usd_per_l=1.1,
        max_usd_per_l=1.5,
        midpoint_usd_per_l=1.3,
        carbon_reduction_pct=0.0,
        maturity_level="incumbent",
    ),
}


DEFAULT_ANALYSIS_PATHWAY_KEY = "hefa"


def list_pathway_costs() -> list[PathwayCostBand]:
    return list(PATHWAY_COSTS.values())


def get_pathway_cost(pathway_key: str) -> PathwayCostBand:
    normalized_key = pathway_key.strip().lower()
    if normalized_key not in PATHWAY_COSTS:
        raise KeyError(pathway_key)
    return PATHWAY_COSTS[normalized_key]


def carbon_credit_usd_per_l(carbon_price_eur_per_t: float, carbon_reduction_pct: float) -> float:
    carbon_price_usd_per_t = carbon_price_eur_per_t * EUR_TO_USD
    avoided_tons_per_l = (FOSSIL_JET_EMISSIONS_KG_PER_L / 1000.0) * (carbon_reduction_pct / 100.0)
    return carbon_price_usd_per_t * avoided_tons_per_l


def effective_saf_cost(
    pathway_key: str,
    *,
    carbon_price_eur_per_t: float = 0.0,
    subsidy_usd_per_l: float = 0.0,
    blend_rate_pct: float = 100.0,
) -> float:
    pathway = get_pathway_cost(pathway_key)
    carbon_credit = carbon_credit_usd_per_l(carbon_price_eur_per_t, pathway.carbon_reduction_pct)
    effective_support = (subsidy_usd_per_l + carbon_credit) * (blend_rate_pct / 100.0)
    return pathway.midpoint_usd_per_l - effective_support
