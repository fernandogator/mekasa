"""
Product health grade + per-member avoidance matching (REQ-021).

Data comes from Open Food Facts (Nutri-Score, NOVA, additives, allergens,
ingredients). The grade is a transparent Yuka-style letter A–E:

    base score   Nutri-Score A/B/C/D/E → 90/75/55/35/15
                 (no Nutri-Score: NOVA 1/2/3/4 → 85/70/50/30; else no grade)
    additives    −25 per high-concern, −10 per moderate, −3 per low (floor 0)
    ultra-proc.  −5 when NOVA 4 and Nutri-Score was the base
    letter       ≥80 A · ≥60 B · ≥40 C · ≥20 D · else E

Avoidances are free text per member ("MSG", "peanuts", "red 40"). A small
synonym catalog maps common names to E-numbers / OFF allergen tags so that
"MSG" hits `en:e621` and "gluten" hits `en:gluten` or "wheat" in ingredients.
"""

from __future__ import annotations

import re
from typing import Iterable

from app.models import (
    AdditiveInfo,
    AvoidanceOption,
    HealthGrade,
    HouseholdMemberResponse,
    MemberWarning,
    ProductHealth,
)

# E-number → (display name, concern). Concern levels follow the public
# EFSA / Yuka-style buckets; unknown additives are listed with concern "unknown".
ADDITIVES: dict[str, tuple[str, str]] = {
    # colours
    "e100": ("Curcumin", "none"),
    "e102": ("Tartrazine (Yellow 5)", "high"),
    "e104": ("Quinoline yellow", "high"),
    "e110": ("Sunset yellow (Yellow 6)", "high"),
    "e120": ("Carmine (cochineal)", "moderate"),
    "e122": ("Azorubine", "high"),
    "e124": ("Ponceau 4R", "high"),
    "e127": ("Erythrosine (Red 3)", "high"),
    "e129": ("Allura red (Red 40)", "high"),
    "e132": ("Indigo carmine (Blue 2)", "moderate"),
    "e133": ("Brilliant blue (Blue 1)", "moderate"),
    "e150a": ("Plain caramel", "none"),
    "e150c": ("Ammonia caramel", "moderate"),
    "e150d": ("Sulphite ammonia caramel", "moderate"),
    "e160a": ("Beta-carotene", "none"),
    "e160b": ("Annatto", "low"),
    "e171": ("Titanium dioxide", "high"),
    # preservatives
    "e200": ("Sorbic acid", "none"),
    "e202": ("Potassium sorbate", "low"),
    "e211": ("Sodium benzoate", "moderate"),
    "e220": ("Sulphur dioxide", "moderate"),
    "e223": ("Sodium metabisulphite", "moderate"),
    "e224": ("Potassium metabisulphite", "moderate"),
    "e249": ("Potassium nitrite", "high"),
    "e250": ("Sodium nitrite", "high"),
    "e251": ("Sodium nitrate", "high"),
    "e252": ("Potassium nitrate", "high"),
    "e282": ("Calcium propionate", "low"),
    # antioxidants / acidity
    "e300": ("Ascorbic acid (vitamin C)", "none"),
    "e319": ("TBHQ", "high"),
    "e320": ("BHA", "high"),
    "e321": ("BHT", "high"),
    "e322": ("Lecithins", "none"),
    "e330": ("Citric acid", "none"),
    "e338": ("Phosphoric acid", "moderate"),
    "e339": ("Sodium phosphates", "moderate"),
    "e340": ("Potassium phosphates", "moderate"),
    "e341": ("Calcium phosphates", "moderate"),
    # thickeners / emulsifiers
    "e407": ("Carrageenan", "moderate"),
    "e412": ("Guar gum", "none"),
    "e415": ("Xanthan gum", "none"),
    "e420": ("Sorbitol", "low"),
    "e433": ("Polysorbate 80", "moderate"),
    "e450": ("Diphosphates", "moderate"),
    "e451": ("Triphosphates", "moderate"),
    "e452": ("Polyphosphates", "moderate"),
    "e460": ("Cellulose", "none"),
    "e466": ("Carboxymethylcellulose", "moderate"),
    "e471": ("Mono- and diglycerides of fatty acids", "low"),
    "e472e": ("DATEM", "low"),
    "e476": ("Polyglycerol polyricinoleate (PGPR)", "low"),
    "e481": ("Sodium stearoyl lactylate", "low"),
    "e500": ("Sodium carbonates (baking soda)", "none"),
    "e501": ("Potassium carbonates", "none"),
    "e503": ("Ammonium carbonates", "none"),
    # flavour enhancers
    "e620": ("Glutamic acid", "moderate"),
    "e621": ("Monosodium glutamate (MSG)", "moderate"),
    "e622": ("Monopotassium glutamate", "moderate"),
    "e627": ("Disodium guanylate", "moderate"),
    "e631": ("Disodium inosinate", "moderate"),
    "e635": ("Disodium ribonucleotides", "moderate"),
    # sweeteners
    "e950": ("Acesulfame K", "moderate"),
    "e951": ("Aspartame", "high"),
    "e952": ("Cyclamate", "moderate"),
    "e954": ("Saccharin", "moderate"),
    "e955": ("Sucralose", "moderate"),
    "e960": ("Steviol glycosides", "none"),
    "e965": ("Maltitol", "low"),
    "e967": ("Xylitol", "low"),
    "e968": ("Erythritol", "low"),
    "e1400": ("Dextrin", "none"),
    "e1442": ("Hydroxypropyl distarch phosphate", "low"),
}

_CONCERN_PENALTY = {"high": 25, "moderate": 10, "low": 3, "none": 0, "unknown": 0}
_NUTRISCORE_BASE = {"a": 90, "b": 75, "c": 55, "d": 35, "e": 15}
_NOVA_BASE = {1: 85, 2: 70, 3: 50, 4: 30}

# Canonical avoidance options offered in the UI. `terms` are lowercase needles
# matched against additive codes/names, allergen + trace tags, and ingredients.
AVOIDANCES: list[AvoidanceOption] = [
    AvoidanceOption(key="msg", label="MSG", terms=["e621", "e620", "e622", "monosodium glutamate", "glutamate", "yeast extract"]),
    AvoidanceOption(key="gluten", label="Gluten", terms=["gluten", "wheat", "barley", "rye", "spelt", "malt"]),
    AvoidanceOption(key="milk", label="Milk / dairy", terms=["milk", "dairy", "lactose", "whey", "casein", "butter", "cream", "cheese"]),
    AvoidanceOption(key="eggs", label="Eggs", terms=["egg", "eggs", "albumin"]),
    AvoidanceOption(key="peanuts", label="Peanuts", terms=["peanut", "peanuts", "groundnut"]),
    AvoidanceOption(key="tree_nuts", label="Tree nuts", terms=["nuts", "almond", "hazelnut", "walnut", "cashew", "pecan", "pistachio", "macadamia"]),
    AvoidanceOption(key="soy", label="Soy", terms=["soy", "soya", "soybean", "soybeans"]),
    AvoidanceOption(key="fish", label="Fish", terms=["fish", "anchovy", "anchovies", "tuna", "salmon", "cod"]),
    AvoidanceOption(key="shellfish", label="Shellfish", terms=["shellfish", "crustaceans", "shrimp", "prawn", "crab", "lobster", "molluscs", "clam", "mussel", "oyster", "squid"]),
    AvoidanceOption(key="sesame", label="Sesame", terms=["sesame", "tahini"]),
    AvoidanceOption(key="mustard", label="Mustard", terms=["mustard"]),
    AvoidanceOption(key="celery", label="Celery", terms=["celery"]),
    AvoidanceOption(key="lupin", label="Lupin", terms=["lupin", "lupine"]),
    AvoidanceOption(key="sulfites", label="Sulfites", terms=["sulfite", "sulfites", "sulphite", "sulphites", "sulphur dioxide", "e220", "e221", "e222", "e223", "e224", "e225", "e226", "e227", "e228"]),
    AvoidanceOption(key="nitrites", label="Nitrites / nitrates", terms=["nitrite", "nitrate", "e249", "e250", "e251", "e252"]),
    AvoidanceOption(key="aspartame", label="Aspartame", terms=["aspartame", "e951"]),
    AvoidanceOption(key="sucralose", label="Sucralose", terms=["sucralose", "e955"]),
    AvoidanceOption(key="artificial_colors", label="Artificial colors", terms=["e102", "e104", "e110", "e122", "e124", "e127", "e129", "e132", "e133", "tartrazine", "red 40", "yellow 5", "yellow 6", "blue 1", "allura red", "sunset yellow"]),
    AvoidanceOption(key="hfcs", label="High-fructose corn syrup", terms=["high fructose corn syrup", "high-fructose corn syrup", "glucose-fructose syrup", "hfcs"]),
    AvoidanceOption(key="palm_oil", label="Palm oil", terms=["palm oil", "palm-oil", "palm fat", "palm kernel"]),
    AvoidanceOption(key="carrageenan", label="Carrageenan", terms=["carrageenan", "e407"]),
    AvoidanceOption(key="bha_bht", label="BHA / BHT / TBHQ", terms=["bha", "bht", "tbhq", "e319", "e320", "e321"]),
    AvoidanceOption(key="caffeine", label="Caffeine", terms=["caffeine", "coffee", "guarana"]),
    AvoidanceOption(key="alcohol", label="Alcohol", terms=["alcohol", "ethanol", "wine", "beer", "liqueur"]),
    AvoidanceOption(key="pork", label="Pork", terms=["pork", "gelatin", "gelatine", "lard", "bacon", "ham"]),
    AvoidanceOption(key="beef", label="Beef", terms=["beef"]),
]

_AVOIDANCE_BY_KEY = {option.key: option for option in AVOIDANCES}
_AVOIDANCE_BY_LABEL = {option.label.casefold(): option for option in AVOIDANCES}

# Free-text aliases the user may type instead of a catalog label.
_ALIASES: dict[str, str] = {
    "monosodium glutamate": "msg",
    "glutamate": "msg",
    "e621": "msg",
    "dairy": "milk",
    "lactose": "milk",
    "wheat": "gluten",
    "nuts": "tree_nuts",
    "nut": "tree_nuts",
    "peanut": "peanuts",
    "egg": "eggs",
    "shrimp": "shellfish",
    "crustaceans": "shellfish",
    "seafood": "shellfish",
    "soya": "soy",
    "sulphites": "sulfites",
    "sulfite": "sulfites",
    "nitrates": "nitrites",
    "nitrate": "nitrites",
    "red 40": "artificial_colors",
    "food coloring": "artificial_colors",
    "food colouring": "artificial_colors",
    "corn syrup": "hfcs",
    "high fructose corn syrup": "hfcs",
    "palm": "palm_oil",
}


def additive_from_tag(tag: str) -> AdditiveInfo | None:
    """`en:e621` / `E621` / `e621i` → AdditiveInfo (unknown codes keep the code as name)."""
    code = tag.split(":", 1)[-1].strip().casefold()
    if not code:
        return None
    match = re.match(r"^(e\d{3,4}[a-z]?)", code)
    if not match:
        return None
    normalized = match.group(1)
    info = ADDITIVES.get(normalized) or ADDITIVES.get(normalized.rstrip("abcdefghij"))
    if info is None:
        return AdditiveInfo(code=normalized.upper(), name=normalized.upper(), concern="unknown")
    name, concern = info
    return AdditiveInfo(code=normalized.upper(), name=name, concern=concern)


def _humanize(tag: str) -> str:
    value = tag.split(":", 1)[-1].replace("-", " ").strip()
    return value[:1].upper() + value[1:] if value else ""


def _dedupe(values: Iterable[str]) -> list[str]:
    seen: set[str] = set()
    ordered: list[str] = []
    for value in values:
        key = value.casefold()
        if value and key not in seen:
            seen.add(key)
            ordered.append(value)
    return ordered


def compute_grade(
    *,
    nutriscore: str | None,
    nova: int | None,
    additives: list[AdditiveInfo],
) -> tuple[HealthGrade | None, int | None]:
    """Return (letter, 0–100 score); (None, None) when there is nothing to grade."""
    nutri = (nutriscore or "").strip().casefold()
    if nutri in _NUTRISCORE_BASE:
        score = _NUTRISCORE_BASE[nutri]
        if nova == 4:
            score -= 5
    elif nova in _NOVA_BASE:
        score = _NOVA_BASE[nova]
    else:
        return None, None
    for additive in additives:
        score -= _CONCERN_PENALTY.get(additive.concern, 0)
    score = max(0, min(100, score))
    if score >= 80:
        letter: HealthGrade = "A"
    elif score >= 60:
        letter = "B"
    elif score >= 40:
        letter = "C"
    elif score >= 20:
        letter = "D"
    else:
        letter = "E"
    return letter, score


def health_from_off_product(product: dict) -> ProductHealth | None:
    """Build ProductHealth from an Open Food Facts product payload; None when OFF has no data."""
    nutriscore_raw = product.get("nutriscore_grade") or product.get("nutrition_grades")
    nutriscore = None
    if isinstance(nutriscore_raw, str) and nutriscore_raw.strip().casefold() in _NUTRISCORE_BASE:
        nutriscore = nutriscore_raw.strip().casefold()

    nova = None
    nova_raw = product.get("nova_group")
    if isinstance(nova_raw, (int, float, str)):
        try:
            candidate = int(str(nova_raw).strip())
            if candidate in _NOVA_BASE:
                nova = candidate
        except ValueError:
            nova = None

    additives: list[AdditiveInfo] = []
    seen_codes: set[str] = set()
    raw_additives = product.get("additives_tags")
    if isinstance(raw_additives, list):
        for tag in raw_additives:
            if not isinstance(tag, str):
                continue
            info = additive_from_tag(tag)
            if info is not None and info.code not in seen_codes:
                seen_codes.add(info.code)
                additives.append(info)

    def _tags(key: str) -> list[str]:
        raw = product.get(key)
        if not isinstance(raw, list):
            return []
        return _dedupe(_humanize(tag) for tag in raw if isinstance(tag, str))

    allergens = _tags("allergens_tags")
    traces = _tags("traces_tags")

    ingredients_raw = product.get("ingredients_text_en") or product.get("ingredients_text")
    ingredients = ingredients_raw.strip() if isinstance(ingredients_raw, str) else None
    if ingredients:
        ingredients = ingredients[:2000]

    analysis = _tags("ingredients_analysis_tags")
    flags = [flag for flag in analysis if flag.casefold() in {"palm oil", "non vegan", "non vegetarian"}]

    if not any((nutriscore, nova, additives, allergens, traces, ingredients)):
        return None

    grade, score = compute_grade(nutriscore=nutriscore, nova=nova, additives=additives)
    return ProductHealth(
        grade=grade,
        score=score,
        nutriscore=nutriscore.upper() if nutriscore else None,
        nova_group=nova,
        additives=additives,
        allergens=allergens,
        traces=traces,
        ingredients_text=ingredients or None,
        flags=flags,
    )


def normalize_avoidance(raw: str) -> str:
    """Map a free-text avoidance to a catalog key when possible, else a trimmed lowercase term."""
    cleaned = " ".join((raw or "").split()).strip().casefold()
    if not cleaned:
        return ""
    if cleaned in _AVOIDANCE_BY_KEY:
        return cleaned
    if cleaned in _AVOIDANCE_BY_LABEL:
        return _AVOIDANCE_BY_LABEL[cleaned].key
    if cleaned in _ALIASES:
        return _ALIASES[cleaned]
    return cleaned[:40]


def avoidance_label(term: str) -> str:
    option = _AVOIDANCE_BY_KEY.get(term)
    if option is not None:
        return option.label
    return term[:1].upper() + term[1:]


def _needles_for(term: str) -> list[str]:
    option = _AVOIDANCE_BY_KEY.get(term)
    if option is not None:
        return [needle.casefold() for needle in option.terms]
    return [term.casefold()]


def _haystack(health: ProductHealth) -> tuple[set[str], str]:
    """(exact tokens, free text) to match needles against."""
    tokens: set[str] = set()
    for additive in health.additives:
        tokens.add(additive.code.casefold())
    for entry in [*health.allergens, *health.traces, *health.flags]:
        tokens.add(entry.casefold())
    text_parts = [
        *(additive.name for additive in health.additives),
        *health.allergens,
        *health.traces,
        *health.flags,
        health.ingredients_text or "",
    ]
    return tokens, " ".join(text_parts).casefold()


def _contains_word(text: str, needle: str) -> bool:
    # Word-ish boundary so "egg" does not match "veggie" while "eggs" still matches "egg".
    pattern = r"(?<![a-z])" + re.escape(needle) + r"(?:s|es)?(?![a-z])"
    return re.search(pattern, text) is not None


def matched_avoidances(avoid: Iterable[str], health: ProductHealth | None) -> list[str]:
    """Return the member's avoidance terms (normalized) that the product triggers."""
    if health is None:
        return []
    tokens, text = _haystack(health)
    hits: list[str] = []
    for raw in avoid:
        term = normalize_avoidance(raw)
        if not term or term in hits:
            continue
        for needle in _needles_for(term):
            if needle in tokens or _contains_word(text, needle):
                hits.append(term)
                break
    return hits


def member_warnings(
    members: Iterable[HouseholdMemberResponse], health: ProductHealth | None
) -> list[MemberWarning]:
    """One warning per active member whose avoid list intersects the product."""
    warnings: list[MemberWarning] = []
    for member in members:
        if member.status != "active" or not member.avoid:
            continue
        hits = matched_avoidances(member.avoid, health)
        if hits:
            warnings.append(
                MemberWarning(
                    member_uid=member.uid,
                    member_name=member.name or member.email or "Household member",
                    matched=[avoidance_label(hit) for hit in hits],
                )
            )
    return warnings
