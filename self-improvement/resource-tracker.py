#!/usr/bin/env python3
"""resource-tracker.py — Track hardware needs and revenue for resource acquisition loop.

Fetches #hardware-need and #revenue memos from the Memos API.
Calculates totals, gaps, and pending needs with ROI estimates.

Usage:
    python3 resource-tracker.py --summary    # Show revenue vs hardware cost summary
    python3 resource-tracker.py --needs      # List pending hardware needs with ROI
    python3 resource-tracker.py --help       # Show this help
"""
import argparse
import json
import os
import re
import sys
import urllib.request
import urllib.error

MEMOS_URL = os.environ.get("MEMOS_URL", "http://nova-rig:5230")
MEMOS_TOKEN = os.environ.get("MEMOS_TOKEN", "")


def api_get(path):
    """GET from Memos API, return parsed JSON."""
    url = "{}{}".format(MEMOS_URL, path)
    req = urllib.request.Request(url)
    if MEMOS_TOKEN:
        req.add_header("Authorization", "Bearer {}".format(MEMOS_TOKEN))
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.URLError as e:
        print("[error] Cannot reach Memos API at {}: {}".format(MEMOS_URL, e), file=sys.stderr)
        return None
    except json.JSONDecodeError:
        print("[error] Invalid JSON from Memos API", file=sys.stderr)
        return None


def search_memos_by_tag(tag):
    """Search memos containing a specific tag."""
    # Memos v1 API: GET /api/v1/memos with filter
    data = api_get("/api/v1/memos?filter=tag==['{}']".format(tag))
    if data is None:
        return []
    # v1 returns {"memos": [...]}
    if isinstance(data, dict) and "memos" in data:
        return data["memos"]
    # Some versions return a list directly
    if isinstance(data, list):
        return data
    return []


def extract_json_blocks(content):
    """Extract JSON blocks from memo content."""
    blocks = []
    pattern = r'```json\s*\n(.*?)\n\s*```'
    for match in re.finditer(pattern, content, re.DOTALL):
        try:
            blocks.append(json.loads(match.group(1)))
        except json.JSONDecodeError:
            continue
    return blocks


def extract_amount(content):
    """Try to extract a dollar amount from memo content."""
    # Look for JSON blocks first
    for block in extract_json_blocks(content):
        if "amount_usd" in block:
            return float(block["amount_usd"])
        if "cost_usd" in block:
            return float(block["cost_usd"])
    # Fallback: regex for $X,XXX or $X.XX patterns
    match = re.search(r'\$[\d,]+(?:\.\d{2})?', content)
    if match:
        return float(match.group().replace('$', '').replace(',', ''))
    return 0.0


def extract_hardware_info(content):
    """Extract hardware need details from memo content."""
    info = {"item": "Unknown", "cost_usd": 0, "bottleneck": "", "roi": "", "priority": "medium"}
    for block in extract_json_blocks(content):
        if block.get("type") == "hardware_need":
            info.update({
                "item": block.get("item", info["item"]),
                "cost_usd": float(block.get("cost_usd", 0)),
                "bottleneck": block.get("bottleneck", ""),
                "roi": block.get("roi", ""),
                "priority": block.get("priority", "medium"),
            })
            return info
    # Fallback: parse from text
    info["cost_usd"] = extract_amount(content)
    item_match = re.search(r'(?:need|want|item)[:\s]+(.+)', content, re.IGNORECASE)
    if item_match:
        info["item"] = item_match.group(1).strip()[:80]
    return info


def show_summary():
    """Show revenue vs hardware cost summary."""
    print("=" * 60)
    print("  RESOURCE ACQUISITION — Summary Report")
    print("=" * 60)
    print()

    # Fetch revenue memos
    revenue_memos = search_memos_by_tag("revenue")
    total_revenue = 0.0
    revenue_entries = []
    for memo in revenue_memos:
        content = memo.get("content", "")
        amount = extract_amount(content)
        total_revenue += amount
        if amount > 0:
            revenue_entries.append({
                "amount": amount,
                "snippet": content[:80].replace('\n', ' '),
            })

    # Fetch hardware need memos
    hardware_memos = search_memos_by_tag("hardware-need")
    total_hardware_cost = 0.0
    for memo in hardware_memos:
        content = memo.get("content", "")
        info = extract_hardware_info(content)
        total_hardware_cost += info["cost_usd"]

    gap = total_hardware_cost - total_revenue
    funded_pct = (total_revenue / total_hardware_cost * 100) if total_hardware_cost > 0 else 0

    print("  Revenue tracked:       ${:,.2f}".format(total_revenue))
    print("  Hardware costs needed:  ${:,.2f}".format(total_hardware_cost))
    print("  Gap (still needed):    ${:,.2f}".format(max(gap, 0)))
    print("  Funded:                {:.1f}%".format(min(funded_pct, 100)))
    print()

    if revenue_entries:
        print("  Recent Revenue:")
        for entry in revenue_entries[-5:]:
            print("    +${:,.2f}  {}".format(entry["amount"], entry["snippet"]))
        print()

    print("  Revenue memos:  {}".format(len(revenue_memos)))
    print("  Hardware memos: {}".format(len(hardware_memos)))
    print()

    if gap > 0:
        print("  >> ${:,.2f} more needed to cover all identified hardware needs.".format(gap))
    elif total_hardware_cost > 0:
        print("  >> All identified hardware needs are funded!")
    else:
        print("  >> No hardware needs logged yet. Use #hardware-need tag in Memos.")

    print()


def show_needs():
    """List pending hardware needs with ROI estimates."""
    print("=" * 60)
    print("  RESOURCE ACQUISITION — Pending Hardware Needs")
    print("=" * 60)
    print()

    hardware_memos = search_memos_by_tag("hardware-need")

    if not hardware_memos:
        print("  No hardware needs logged yet.")
        print("  Log needs in Memos with #hardware-need tag.")
        print()
        print("  Expected format (JSON block in memo):")
        print('  {')
        print('    "type": "hardware_need",')
        print('    "item": "128GB Thor module",')
        print('    "cost_usd": 2000,')
        print('    "bottleneck": "inference_speed",')
        print('    "improvement": "2x context window",')
        print('    "roi": "Eliminates cloud API costs (~$200/mo)",')
        print('    "priority": "high"')
        print('  }')
        print()
        return

    priority_order = {"critical": 0, "high": 1, "medium": 2, "low": 3}
    needs = []
    for memo in hardware_memos:
        content = memo.get("content", "")
        info = extract_hardware_info(content)
        info["memo_name"] = memo.get("name", memo.get("uid", "unknown"))
        needs.append(info)

    needs.sort(key=lambda n: priority_order.get(n["priority"], 9))

    for i, need in enumerate(needs, 1):
        pri = need["priority"].upper()
        print("  [{}] {}. {}".format(pri, i, need["item"]))
        print("         Cost: ${:,.2f}".format(need["cost_usd"]))
        if need["bottleneck"]:
            print("         Bottleneck: {}".format(need["bottleneck"]))
        if need["roi"]:
            print("         ROI: {}".format(need["roi"]))
        print()

    total = sum(n["cost_usd"] for n in needs)
    print("  Total hardware cost: ${:,.2f}".format(total))
    print("  Items: {}".format(len(needs)))
    print()


def main():
    parser = argparse.ArgumentParser(
        description="Track hardware needs and revenue for the resource acquisition loop.",
        epilog="Fetches data from Memos API (#hardware-need, #revenue tags).",
    )
    parser.add_argument("--summary", action="store_true", help="Show revenue vs hardware cost summary")
    parser.add_argument("--needs", action="store_true", help="List pending hardware needs with ROI")
    args = parser.parse_args()

    if not args.summary and not args.needs:
        parser.print_help()
        return

    if args.summary:
        show_summary()
    if args.needs:
        show_needs()


if __name__ == "__main__":
    main()
