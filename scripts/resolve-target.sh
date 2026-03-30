#!/usr/bin/env bash
# resolve-target.sh — Determine the recommended Node.js upgrade target
#
# Fetches the official Node.js release schedule and outputs the most recent
# Active LTS version. This is deterministic — no AI reasoning needed.
#
# Usage: bash scripts/resolve-target.sh
# Output: prints the recommended target version and release context
#
# Source: https://github.com/nodejs/Release (same data as
#         https://nodejs.org/en/about/previous-releases)

set -euo pipefail

CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCHEDULE_URL="https://raw.githubusercontent.com/nodejs/Release/main/schedule.json"
TODAY=$(date +%Y-%m-%d)

schedule=$(curl -sf "$SCHEDULE_URL" 2>/dev/null || true)

if [ -z "$schedule" ]; then
  echo -e "${YELLOW}Could not fetch release schedule from $SCHEDULE_URL${NC}" >&2
  echo -e "${YELLOW}Check https://nodejs.org/en/about/previous-releases manually${NC}" >&2
  exit 1
fi

# Use python3 (available on macOS and most Linux) to parse JSON and determine status
python3 -c "
import json, sys
from datetime import date

schedule = json.loads('''$schedule''')
today = date.fromisoformat('$TODAY')

versions = []
for key, info in schedule.items():
    ver = int(key.lstrip('v').split('.')[0]) if key.lstrip('v').split('.')[0].isdigit() else 0
    if ver < 10:
        continue
    start = date.fromisoformat(info.get('start', '2099-01-01'))
    lts = date.fromisoformat(info['lts']) if 'lts' in info else None
    maint = date.fromisoformat(info['maintenance']) if 'maintenance' in info else None
    end = date.fromisoformat(info.get('end', '2099-01-01'))
    codename = info.get('codename', '')

    if end < today:
        status = 'EOL'
    elif maint and maint <= today:
        status = 'Maintenance LTS'
    elif lts and lts <= today and (not maint or maint > today):
        status = 'Active LTS'
    elif start <= today and (not lts or lts > today):
        status = 'Current'
    elif start > today:
        status = 'Upcoming'
    else:
        status = 'Unknown'

    versions.append({
        'ver': ver,
        'key': key,
        'status': status,
        'lts': lts,
        'maint': maint,
        'end': end,
        'codename': codename,
        'start': start,
    })

versions.sort(key=lambda x: x['ver'], reverse=True)

# Find Active LTS versions (most recent first)
active_lts = [v for v in versions if v['status'] == 'Active LTS']
maint_lts = [v for v in versions if v['status'] == 'Maintenance LTS']
current = [v for v in versions if v['status'] == 'Current']

print()
print('Node.js Release Landscape (' + '$TODAY' + ')')
print('=' * 55)
print(f\"{'Version':<12} {'Status':<20} {'EOL':<12} {'Codename'}\")
print('-' * 55)
for v in versions:
    if v['status'] in ('EOL', 'Upcoming', 'Unknown'):
        continue
    print(f\"{v['key']:<12} {v['status']:<20} {str(v['end']):<12} {v['codename']}\")

print()
if active_lts:
    target = active_lts[0]
    print(f\"RECOMMENDED TARGET: Node.js {target['ver']} ({target['codename']}) — Active LTS\")
    print(f\"  LTS since:      {target['lts']}\")
    print(f\"  Maintenance:    {target['maint']}\")
    print(f\"  End of Life:    {target['end']}\")
    if maint_lts:
        alt = maint_lts[0]
        print()
        print(f\"CONSERVATIVE ALT:   Node.js {alt['ver']} ({alt['codename']}) — Maintenance LTS until {alt['end']}\")
else:
    print('WARNING: No Active LTS version found. Check https://nodejs.org/en/about/previous-releases')

if current:
    c = current[0]
    print()
    print(f\"NOTE: Node.js {c['ver']} is Current (not LTS) — not recommended for production\")

print()
" 2>&1
