"""Генерация SVG топологии Data Guard из oracle-meta.json."""


def _xml(s: str) -> str:
    return (
        str(s)
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def version_label(site: str, sites: dict) -> str:
    s = sites.get(site) or {}
    if s.get("version"):
        return f"Oracle {s['version']}"
    banner = s.get("banner") or ""
    if "Release" in banner:
        import re

        m = re.search(r"Release\s+([\d.]+)", banner)
        if m:
            return f"Oracle {m.group(1)}"
    return "Oracle"


def build_topology_svg(meta: dict) -> str:
    primary = meta["primary_site"]
    standby = meta["standby_site"]
    sites = meta["sites"]
    left, right = primary, standby
    left_ver = _xml(version_label(left, sites))
    right_ver = _xml(version_label(right, sites))
    left_fill, left_stroke = "#047857", "#059669"
    right_fill, right_stroke = "#0369a1", "#0284c7"

    return f"""<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 520 220" style="max-width:100%;height:auto;">
  <defs>
    <linearGradient id="primaryCylTop" x1="0%" y1="0%" x2="0%" y2="100%"><stop offset="0%" style="stop-color:#a7f3d0"/><stop offset="100%" style="stop-color:#6ee7b7"/></linearGradient>
    <linearGradient id="primaryCylBody" x1="0%" y1="0%" x2="100%" y2="0%"><stop offset="0%" style="stop-color:#5eead4"/><stop offset="50%" style="stop-color:#99f6e4"/><stop offset="100%" style="stop-color:#5eead4"/></linearGradient>
    <linearGradient id="standbyCylTop" x1="0%" y1="0%" x2="0%" y2="100%"><stop offset="0%" style="stop-color:#7dd3fc"/><stop offset="100%" style="stop-color:#38bdf8"/></linearGradient>
    <linearGradient id="standbyCylBody" x1="0%" y1="0%" x2="100%" y2="0%"><stop offset="0%" style="stop-color:#38bdf8"/><stop offset="50%" style="stop-color:#bae6fd"/><stop offset="100%" style="stop-color:#38bdf8"/></linearGradient>
    <marker id="arrowhead" markerWidth="12" markerHeight="8" refX="10" refY="4" orient="auto"><polygon points="0 0, 12 4, 0 8" fill="#0ea5e9"/></marker>
    <filter id="shadow" x="-20%" y="-10%" width="140%" height="120%"><feDropShadow dx="0" dy="3" stdDeviation="4" flood-opacity="0.12"/></filter>
    <linearGradient id="arrowGrad" x1="0%" y1="0%" x2="100%" y2="0%"><stop offset="0%" style="stop-color:#059669"/><stop offset="100%" style="stop-color:#0ea5e9"/></linearGradient>
  </defs>
  <a xlink:href="/d/primary-overview/primary-overview" style="cursor:pointer;">
    <g>
      <rect x="15" y="30" width="155" height="165" fill="transparent"/>
      <g filter="url(#shadow)" transform="translate(50, 35)">
        <path d="M 35 25 L 35 95 A 35 12 0 0 0 105 95 L 105 25 Z" fill="url(#primaryCylBody)" stroke="{left_stroke}" stroke-width="2"/>
        <ellipse cx="70" cy="25" rx="35" ry="12" fill="url(#primaryCylTop)" stroke="{left_stroke}" stroke-width="2"/>
        <ellipse cx="70" cy="48" rx="32" ry="4" fill="none" stroke="{left_fill}" stroke-width="1.2" opacity="0.7"/>
        <ellipse cx="70" cy="72" rx="32" ry="4" fill="none" stroke="{left_fill}" stroke-width="1.2" opacity="0.7"/>
        <ellipse cx="70" cy="96" rx="32" ry="4" fill="none" stroke="{left_fill}" stroke-width="1.2" opacity="0.5"/>
      </g>
      <text x="110" y="155" text-anchor="middle" font-family="system-ui,sans-serif" font-size="11" font-weight="600" fill="#065f46">PRIMARY</text>
      <text x="110" y="172" text-anchor="middle" font-family="system-ui,sans-serif" font-size="14" font-weight="700" fill="{left_fill}">{_xml(left)}</text>
      <text x="110" y="190" text-anchor="middle" font-family="system-ui,sans-serif" font-size="9" fill="#6b7280">{left_ver}</text>
    </g>
  </a>
  <a xlink:href="/d/replication-overview/replication-overview" style="cursor:pointer;">
    <g>
      <rect x="170" y="92" width="180" height="36" fill="transparent"/>
      <path d="M 175 110 L 345 110" stroke="#cbd5e1" stroke-width="4" fill="none" stroke-linecap="round"/>
      <path d="M 175 110 L 345 110" stroke="url(#arrowGrad)" stroke-width="3" fill="none" stroke-linecap="round" marker-end="url(#arrowhead)"/>
      <path d="M 175 110 L 332 110" stroke="#0ea5e9" stroke-width="2" fill="none" stroke-dasharray="8 16" stroke-linecap="round"><animate attributeName="stroke-dashoffset" from="24" to="0" dur="1.2s" repeatCount="indefinite"/></path>
      <circle r="5" fill="#059669"><animateMotion dur="2s" repeatCount="indefinite" path="M 175 110 L 332 110"/></circle>
      <circle r="4" fill="#0ea5e9"><animateMotion dur="2s" repeatCount="indefinite" path="M 175 110 L 332 110" begin="0.5s"/></circle>
      <circle r="4" fill="#0ea5e9"><animateMotion dur="2s" repeatCount="indefinite" path="M 175 110 L 332 110" begin="1s"/></circle>
      <text x="260" y="98" text-anchor="middle" font-family="system-ui,sans-serif" font-size="10" fill="#64748b">Data Guard (replication)</text>
    </g>
  </a>
  <a xlink:href="/d/standby-overview/standby-overview" style="cursor:pointer;">
    <g>
      <rect x="318" y="30" width="195" height="165" fill="transparent"/>
      <g filter="url(#shadow)" transform="translate(360, 35)">
        <path d="M 35 25 L 35 95 A 35 12 0 0 0 105 95 L 105 25 Z" fill="url(#standbyCylBody)" stroke="{right_stroke}" stroke-width="2"/>
        <ellipse cx="70" cy="25" rx="35" ry="12" fill="url(#standbyCylTop)" stroke="{right_stroke}" stroke-width="2"/>
        <ellipse cx="70" cy="48" rx="32" ry="4" fill="none" stroke="{right_fill}" stroke-width="1.2" opacity="0.7"/>
        <ellipse cx="70" cy="72" rx="32" ry="4" fill="none" stroke="{right_fill}" stroke-width="1.2" opacity="0.7"/>
        <ellipse cx="70" cy="96" rx="32" ry="4" fill="none" stroke="{right_fill}" stroke-width="1.2" opacity="0.5"/>
      </g>
      <text x="410" y="155" text-anchor="middle" font-family="system-ui,sans-serif" font-size="11" font-weight="600" fill="#075985">STANDBY</text>
      <text x="410" y="172" text-anchor="middle" font-family="system-ui,sans-serif" font-size="14" font-weight="700" fill="{right_fill}">{_xml(right)}</text>
      <text x="410" y="190" text-anchor="middle" font-family="system-ui,sans-serif" font-size="9" fill="#6b7280">{right_ver}</text>
    </g>
  </a>
</svg>"""


def build_panel_html(meta: dict) -> str:
    svg = build_topology_svg(meta)
    status = (
        f"Primary: <b>{meta['primary_site']}</b> → Standby: <b>{meta['standby_site']}</b>"
        f" · обновлено {meta.get('updated_at', '')}"
    )
    return (
        f'<div style="text-align:center;">{svg}'
        f'<p style="font-size:11px;color:#94a3b8;margin:8px 0 0;">{status}</p></div>'
    )
