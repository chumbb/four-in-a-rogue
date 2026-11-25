"""Goob stats from tester play data (M6g, Sean 2026-11-25).

Reads `scenario_end` events (sent by Telemetry from exported builds) and prints
a Markdown report:

- every Goob's win rate when in the deck, when played and when in the winning four
- win rates of Goob pairs played by the same side in one game, with the lift
  over the two Goobs alone
- held in hand vs played at once: turns held, % played the turn it was drawn,
  % never played (left in hand or discarded)

The player side counts only games a person played: no auto-play, no F4 debug
games. The opponent (the AI) is reported separately. Draws count as games
that were not won. Every rate shows its sample size and a 95 % Wilson interval;
with only a few testers, trust the big samples only.

Sources:
  PostHog (needs a *personal* API key with query:read, never put in git):
    set POSTHOG_PERSONAL_KEY=phx_...
    python tools/telemetry/goob_stats.py --project <project id> [--host https://us.posthog.com]
  A file (one event JSON per line, or a JSON list; e.g. a PostHog export):
    python tools/telemetry/goob_stats.py --file events.jsonl

Options: --min-pair N (default 5), --out report.md, --include-vanilla
(Vanilla in pairs), --include-autoplay (your auto-play games too),
--since 2026-11-25.
"""

from __future__ import annotations

import argparse
import itertools
import json
import math
import os
import re
import sys
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SIDES = ("player", "opponent")
PAGE = 5000


def wilson(wins: int, n: int, z: float = 1.96) -> tuple[float, float]:
    if n == 0:
        return (0.0, 0.0)
    p = wins / n
    d = 1 + z * z / n
    centre = (p + z * z / (2 * n)) / d
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return (max(0.0, centre - half), min(1.0, centre + half))


def rate(wins: int, n: int) -> str:
    if n == 0:
        return "–"
    lo, hi = wilson(wins, n)
    return f"{100 * wins / n:.0f}% ({100 * lo:.0f}–{100 * hi:.0f})"


def goob_names() -> dict[str, str]:
    names = {}
    for tres in (ROOT / "resources" / "goobs").glob("*.tres"):
        text = tres.read_text(encoding="utf-8")
        gid = re.search(r'^id = "([^"]*)"', text, re.M)
        name = re.search(r'^display_name = "([^"]*)"', text, re.M)
        if gid:
            names[gid.group(1)] = name.group(1) if name else gid.group(1)
    names["vanilla"] = "Goob"
    return names


def load_file(path: str) -> list[dict]:
    text = Path(path).read_text(encoding="utf-8").strip()
    if text.startswith("["):
        rows = json.loads(text)
    else:
        rows = [json.loads(line) for line in text.splitlines() if line.strip()]
    out = []
    for row in rows:
        # A queue line {event, properties} or a bare properties dict.
        if "properties" in row:
            if row.get("event", "scenario_end") != "scenario_end":
                continue
            props = row["properties"]
            if isinstance(props, str):
                props = json.loads(props)
            out.append(props)
        else:
            out.append(row)
    return out


def load_posthog(host: str, project: str, key: str, since: str | None) -> list[dict]:
    where = "event = 'scenario_end'"
    if since:
        where += f" AND timestamp >= toDateTime('{since}')"
    out: list[dict] = []
    offset = 0
    while True:
        query = f"SELECT properties FROM events WHERE {where} ORDER BY timestamp LIMIT {PAGE} OFFSET {offset}"
        body = json.dumps({"query": {"kind": "HogQLQuery", "query": query}}).encode()
        req = urllib.request.Request(
            f"{host.rstrip('/')}/api/projects/{project}/query/",
            data=body,
            headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        )
        with urllib.request.urlopen(req, timeout=60) as resp:
            results = json.load(resp).get("results", [])
        for (props,) in results:
            out.append(json.loads(props) if isinstance(props, str) else props)
        if len(results) < PAGE:
            return out
        offset += PAGE


def side_won(props: dict, side: str) -> bool:
    return props.get("result") == ("win" if side == "player" else "lose")


def counts_for(props: dict, side: str, include_autoplay: bool = False) -> bool:
    if props.get("debug"):
        return False
    if side == "player" and props.get("autoplay_used") and not include_autoplay:
        return False
    return True


def report(games: list[dict], min_pair: int, include_vanilla: bool, include_autoplay: bool = False) -> str:
    names = goob_names()
    nm = lambda gid: names.get(gid, gid)  # noqa: E731
    lines = ["# Goob stats", ""]
    results = Counter(g.get("result", "?") for g in games)
    lines.append(f"{len(games)} scenarios: {results.get('win', 0)} player wins, {results.get('lose', 0)} losses, {results.get('draw', 0)} draws.")
    lines.append("")
    for side in SIDES:
        rows = [g for g in games if counts_for(g, side, include_autoplay)]
        title = "You (human games only)" if side == "player" else "Opponent (AI)"
        lines += [f"## {title}", ""]
        if not rows:
            lines += ["No games yet.", ""]
            continue
        wins = sum(side_won(g, side) for g in rows)
        lines += [f"{len(rows)} games, win rate {rate(wins, len(rows))}.", ""]

        in_deck = Counter()
        in_deck_w = Counter()
        played_g = Counter()
        played_w = Counter()
        plays = Counter()
        line_n = Counter()
        held: dict[str, list[int]] = defaultdict(list)
        unplayed = Counter()
        pair_n = Counter()
        pair_w = Counter()
        for g in rows:
            won = side_won(g, side)
            deck = set(g.get(f"{side}_deck", []))
            played = g.get(f"{side}_played", [])
            for gid in deck:
                in_deck[gid] += 1
                in_deck_w[gid] += won
            for gid in set(played):
                played_g[gid] += 1
                played_w[gid] += won
            for gid, h in zip(played, g.get(f"{side}_held", [])):
                plays[gid] += 1
                if isinstance(h, (int, float)) and h >= 0:
                    held[gid].append(int(h))
            for gid in g.get(f"{side}_left_in_hand", []) + g.get(f"{side}_discarded", []):
                unplayed[gid] += 1
            for gid in set(g.get(f"{side}_winning_line", [])):
                line_n[gid] += 1
            distinct = sorted(gid for gid in set(played) if include_vanilla or gid != "vanilla")
            for a, b in itertools.combinations(distinct, 2):
                pair_n[(a, b)] += 1
                pair_w[(a, b)] += won

        lines += [
            "### Win rate per Goob",
            "",
            "| Goob | In deck (games) | Win rate in deck | Played (games) | Win rate when played | In winning four |",
            "|---|---:|---:|---:|---:|---:|",
        ]
        for gid in sorted(in_deck, key=lambda k: (-played_g[k], k)):
            lines.append(
                f"| {nm(gid)} | {in_deck[gid]} | {rate(in_deck_w[gid], in_deck[gid])} | "
                f"{played_g[gid]} | {rate(played_w[gid], played_g[gid])} | {line_n[gid]} |"
            )
        lines += [
            "",
            "### Held in hand vs played at once",
            "",
            "Turns held = that side's turns between drawing a Goob and playing it (0 = played the turn it was drawn; the starting hand counts as drawn on turn 1). Never played = left in hand at the end or discarded.",
            "",
            "| Goob | Plays | Played at once | Avg turns held | Max held | Never played |",
            "|---|---:|---:|---:|---:|---:|",
        ]
        for gid in sorted(plays, key=lambda k: (-plays[k], k)):
            h = held[gid]
            at_once = sum(1 for x in h if x == 0)
            seen = plays[gid] + unplayed[gid]
            lines.append(
                f"| {nm(gid)} | {plays[gid]} | {rate(at_once, len(h)) if h else '–'} | "
                f"{(sum(h) / len(h)) if h else 0:.1f} | {max(h) if h else '–'} | {rate(unplayed[gid], seen)} |"
            )
        lines += [
            "",
            f"### Pairs played together (same side, same game; at least {min_pair} games)",
            "",
            "Lift = the pair's win rate minus the average of the two Goobs' own win rates when played.",
            "",
            "| Pair | Games | Win rate | Lift |",
            "|---|---:|---:|---:|",
        ]
        shown = 0
        for (a, b), n in sorted(pair_n.items(), key=lambda kv: (-kv[1], kv[0])):
            if n < min_pair:
                continue
            w = pair_w[(a, b)]
            alone = (played_w[a] / played_g[a] + played_w[b] / played_g[b]) / 2
            lines.append(f"| {nm(a)} + {nm(b)} | {n} | {rate(w, n)} | {100 * (w / n - alone):+.0f} pts |")
            shown += 1
        if shown == 0:
            lines.append(f"| (no pair has {min_pair}+ games yet) | | | |")
        lines.append("")
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--file")
    ap.add_argument("--project", help="PostHog project id")
    ap.add_argument("--host", default="https://us.posthog.com", help="PostHog app host (us.posthog.com / eu.posthog.com)")
    ap.add_argument("--since")
    ap.add_argument("--min-pair", type=int, default=5)
    ap.add_argument("--include-vanilla", action="store_true")
    ap.add_argument("--include-autoplay", action="store_true", help="count your auto-play games too (soak runs)")
    ap.add_argument("--out")
    args = ap.parse_args()
    if args.file:
        games = load_file(args.file)
    elif args.project:
        key = os.environ.get("POSTHOG_PERSONAL_KEY", "")
        if not key:
            print("Set POSTHOG_PERSONAL_KEY (a personal API key with query:read).", file=sys.stderr)
            return 2
        games = load_posthog(args.host, args.project, key, args.since)
    else:
        ap.print_help()
        return 2
    text = report(games, args.min_pair, args.include_vanilla, args.include_autoplay)
    if args.out:
        Path(args.out).write_text(text, encoding="utf-8")
        print(f"Wrote {args.out} ({len(games)} scenarios)")
    else:
        sys.stdout.reconfigure(encoding="utf-8")
        print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
