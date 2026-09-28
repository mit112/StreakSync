#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["PyJWT[crypto]>=2.8"]
# ///
"""Read-only App Store Connect status for StreakSync.

    uv run scripts/asc_status.py builds [--version 1.25]   TestFlight builds + processing state
    uv run scripts/asc_status.py versions                   App Store versions + review state
    uv run scripts/asc_status.py check 1.25                 exit 0 iff a VALID build of that version exists

Credentials (team API key, App Store Connect > Users and Access > Integrations):
    ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8   (altool's default location)
    ~/.appstoreconnect/config.json  {"key_id": "...", "issuer_id": "..."}
ASC_KEY_ID / ASC_ISSUER_ID in the environment override the config file.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

import jwt

BASE = "https://api.appstoreconnect.apple.com/v1"
BUNDLE_ID = "com.mitsheth.StreakSync"
CONFIG_DIR = Path.home() / ".appstoreconnect"


def load_credentials() -> tuple[str, str, str]:
    config: dict[str, str] = {}
    config_path = CONFIG_DIR / "config.json"
    if config_path.exists():
        config = json.loads(config_path.read_text())
    key_id = os.environ.get("ASC_KEY_ID") or config.get("key_id", "")
    issuer_id = os.environ.get("ASC_ISSUER_ID") or config.get("issuer_id", "")
    if not key_id or not issuer_id:
        sys.exit(
            f"Missing key_id/issuer_id. Put them in {config_path} or set ASC_KEY_ID / ASC_ISSUER_ID."
        )
    key_path = CONFIG_DIR / "private_keys" / f"AuthKey_{key_id}.p8"
    if not key_path.exists():
        sys.exit(f"Private key not found at {key_path}")
    return key_id, issuer_id, key_path.read_text()


def make_token(key_id: str, issuer_id: str, private_key: str) -> str:
    now = int(time.time())
    payload = {"iss": issuer_id, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"}
    return jwt.encode(payload, private_key, algorithm="ES256", headers={"kid": key_id})


def get(token: str, path: str, params: dict[str, str] | None = None) -> dict:
    url = f"{BASE}{path}"
    if params:
        url += "?" + urllib.parse.urlencode(params)
    request = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        body = error.read().decode(errors="replace")
        try:
            detail = "; ".join(e.get("detail", e.get("title", "")) for e in json.loads(body)["errors"])
        except (ValueError, KeyError):
            detail = body[:300]
        sys.exit(f"HTTP {error.code} from {path}: {detail}")


def app_id(token: str) -> str:
    data = get(token, "/apps", {"filter[bundleId]": BUNDLE_ID, "fields[apps]": "name"})["data"]
    if not data:
        sys.exit(f"No app with bundle id {BUNDLE_ID} visible to this key.")
    return data[0]["id"]


def fetch_builds(token: str, version: str | None) -> list[dict]:
    params = {
        "filter[app]": app_id(token),
        "sort": "-uploadedDate",
        "limit": "20",
        "include": "preReleaseVersion",
        "fields[builds]": "version,uploadedDate,processingState,expired,preReleaseVersion",
        "fields[preReleaseVersions]": "version,platform",
    }
    if version:
        params["filter[preReleaseVersion.version]"] = version
    payload = get(token, "/builds", params)
    marketing = {
        item["id"]: item["attributes"]["version"]
        for item in payload.get("included", [])
        if item["type"] == "preReleaseVersions"
    }
    rows = []
    for build in payload["data"]:
        attrs = build["attributes"]
        pre = build["relationships"]["preReleaseVersion"]["data"]
        rows.append(
            {
                "version": marketing.get(pre["id"], "?") if pre else "?",
                "build": attrs["version"],
                "state": attrs["processingState"],
                "expired": attrs["expired"],
                "uploaded": (attrs.get("uploadedDate") or "")[:19],
            }
        )
    return rows


def cmd_builds(token: str, args: argparse.Namespace) -> int:
    rows = fetch_builds(token, args.version)
    if not rows:
        print("No builds found." + (f" (version {args.version})" if args.version else ""))
        return 1
    print(f"{'version':<8} {'build':<6} {'state':<11} {'expired':<7} uploaded (UTC)")
    for row in rows:
        print(f"{row['version']:<8} {row['build']:<6} {row['state']:<11} {str(row['expired']):<7} {row['uploaded']}")
    return 0


def cmd_versions(token: str, _: argparse.Namespace) -> int:
    payload = get(
        token,
        f"/apps/{app_id(token)}/appStoreVersions",
        {"fields[appStoreVersions]": "versionString,appStoreState,createdDate", "limit": "10"},
    )
    print(f"{'version':<8} {'state':<32} created (UTC)")
    for item in payload["data"]:
        attrs = item["attributes"]
        print(f"{attrs['versionString']:<8} {attrs['appStoreState']:<32} {attrs['createdDate'][:19]}")
    return 0


def cmd_check(token: str, args: argparse.Namespace) -> int:
    rows = fetch_builds(token, args.version)
    valid = [r for r in rows if r["state"] == "VALID" and not r["expired"]]
    if valid:
        newest = valid[0]
        print(f"OK: {args.version} ({newest['build']}) is VALID in TestFlight, uploaded {newest['uploaded']}Z")
        return 0
    if rows:
        print(f"NOT READY: {args.version} has {len(rows)} build(s) but none VALID: " + ", ".join(r["state"] for r in rows))
    else:
        print(f"MISSING: no build of {args.version} has reached App Store Connect")
    return 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    builds = sub.add_parser("builds")
    builds.add_argument("--version", help="marketing version, e.g. 1.25")
    builds.set_defaults(run=cmd_builds)
    versions = sub.add_parser("versions")
    versions.set_defaults(run=cmd_versions)
    check = sub.add_parser("check")
    check.add_argument("version")
    check.set_defaults(run=cmd_check)
    args = parser.parse_args()
    token = make_token(*load_credentials())
    return args.run(token, args)


if __name__ == "__main__":
    sys.exit(main())
