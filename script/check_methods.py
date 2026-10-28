#!/usr/bin/env python3
"""Status of the DIF-recommended DID methods and did:oyd.

Validates the example DIDs listed in status/methods.json with a DID Linter
instance (GET /api/validate/{did}) and writes the result as JSON. The
workflow 'methods' runs this daily against https://didlint.ownyourdata.eu
and publishes the result as
https://ownyourdata.github.io/didlint/dif-methods.json, which the start page
of DID Linter shows.

Every example DID gets one status:

  conforms        the resolved DID document conforms ("notes" counts the
                  notes that do not change the result)
  violations      the DID document was resolved and does not conform;
                  "errors" lists the findings as the API returns them
  not_resolvable  the resolver found no DID document; "message" is the
                  answer of the instance
  error           no result: the instance did not answer as expected, the
                  resolver timed out or its request limit was reached

Resolvers fail now and then, so a DID without a result is checked twice
more, after 15 and 45 seconds; when the request limit of the Universal
Resolver is reached, retrying soon does not help and is skipped.

With --previous (the result published before, URL or file):
  - "since" keeps the time from which a DID has had its current status,
  - a DID without a result this time keeps its previous result, with
    "checked" telling when that result was obtained and "failed" telling
    why this check got none.
Without --previous every entry is from this check.

Exit code 0 when the result was written, 1 when the instance is not
reachable (nothing is written, so a published status stays as it was), 2 on
usage errors. Only the Python standard library is used.
"""

import argparse
import datetime
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
METHODS = os.path.join(ROOT, "status", "methods.json")
TIMEOUT = 60
RETRY_DELAYS = (15, 45)
PAUSE = 2
LIMIT_ERROR = "Universal Resolver request limit reached, please try again later"
# answers of the instance that say nothing about the DID itself
TRANSIENT_ERRORS = (LIMIT_ERROR, "time out", "invalid Uniresolver response")
STATUS_TEXT = {
    "conforms": "conforms",
    "violations": "violations",
    "not_resolvable": "not resolvable",
    "error": "no result",
}
DETAILS = ("notes", "errors", "message")


def http_get(url):
    req = urllib.request.Request(url, headers={"Accept": "application/json", "User-Agent": "didlint-check-methods"})
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            return resp.status, resp.read().decode("utf-8")
    except urllib.error.HTTPError as err:
        return err.code, err.read().decode("utf-8", "replace")
    except (urllib.error.URLError, OSError) as err:
        # not reachable: status 0, the reason as body
        return 0, str(getattr(err, "reason", err))


def parse(body):
    try:
        return json.loads(body)
    except ValueError:
        return None


def classify(code, body):
    """Maps a response of GET /api/validate/{did} to a status and its details."""
    data = parse(body)
    if code == 200 and isinstance(data, dict) and isinstance(data.get("valid"), bool):
        if data["valid"]:
            return {"status": "conforms", "notes": len(data.get("infos") or [])}
        return {"status": "violations", "errors": data.get("errors") or []}
    if code == 422 and isinstance(data, dict) and data.get("error"):
        message = str(data["error"])
        return {"status": "error" if message in TRANSIENT_ERRORS else "not_resolvable", "message": message}
    if code == 0:
        return {"status": "error", "message": "instance not reachable: " + body}
    return {"status": "error", "message": "HTTP " + str(code)}


def check(url, did):
    target = url + "/api/validate/" + urllib.parse.quote(did, safe=":%")
    result = classify(*http_get(target))
    for delay in RETRY_DELAYS:
        if result["status"] not in ("not_resolvable", "error") or result.get("message") == LIMIT_ERROR:
            break
        time.sleep(delay)
        result = classify(*http_get(target))
    time.sleep(PAUSE)
    return result


def load_previous(source):
    """The previously published result as {did: entry}; empty if unavailable."""
    if not source:
        return {}
    if source.startswith("https://") or source.startswith("http://"):
        code, body = http_get(source)
        data = parse(body) if code == 200 else None
    else:
        try:
            with open(source, encoding="utf-8") as f:
                data = parse(f.read())
        except OSError:
            data = None
    if not isinstance(data, dict):
        return {}
    previous = {}
    for method in data.get("methods") or []:
        for entry in method.get("dids") or []:
            if isinstance(entry, dict) and entry.get("did") and entry.get("status") in STATUS_TEXT:
                previous[entry["did"]] = entry
    return previous


def entry_for(did, result, before, generated):
    """The published entry: this check's result, or the previous one if this check got none."""
    if result["status"] == "error" and before and before.get("status") != "error":
        entry = {key: before[key] for key in ("did", "status") + DETAILS if key in before}
        entry["since"] = before.get("since") or generated
        entry["checked"] = before.get("checked") or before.get("since") or generated
        entry["failed"] = {"at": generated, "message": result["message"]}
        return entry
    entry = dict({"did": did}, **result)
    same = before and before.get("status") == result["status"]
    entry["since"] = before["since"] if same and before.get("since") else generated
    entry["checked"] = generated
    return entry


def now():
    return datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def describe(entry):
    text = STATUS_TEXT[entry["status"]]
    if entry["status"] == "violations":
        text += ": " + "; ".join(
            str(e.get("value", "")).split("/")[-1] + " " + str(e.get("error", "")) for e in entry["errors"])
    elif entry.get("message"):
        text += ": " + entry["message"]
    if entry.get("failed"):
        text += " (no result this time: " + entry["failed"]["message"] + ")"
    return text.replace("|", "\\|")


def summary(result, changes, compared):
    lines = [
        "### DID methods checked with DID Linter " + str(result["version"]),
        "",
        "Instance " + result["instance"] + ", structure `" + str(result["did-dri"]) + "`, " + result["generated"],
        "",
        "| Method | DID | Status | Since | Checked |",
        "|---|---|---|---|---|",
    ]
    for method in result["methods"]:
        if not method["dids"]:
            lines.append("| `" + method["method"] + "` | - | " + method.get("note", "no example DID") + " | | |")
        for entry in method["dids"]:
            lines.append("| `" + method["method"] + "` | `" + entry["did"] + "` | " + describe(entry) +
                         " | " + entry["since"] + " | " + entry["checked"] + " |")
    lines.append("")
    if not compared:
        lines.append("No previous result to compare with.")
    elif changes:
        lines.append("Changed since the previous check:")
        lines.append("")
        lines.extend("- `" + did + "`: " + before + " → " + after for did, before, after in changes)
    else:
        lines.append("No change since the previous check.")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--url", default="https://didlint.ownyourdata.eu", help="DID Linter instance")
    parser.add_argument("--methods", default=METHODS, help="methods and example DIDs (default status/methods.json)")
    parser.add_argument("--previous", default="", help="previous result, URL or file")
    parser.add_argument("--output", default="-", help="result file (default stdout)")
    parser.add_argument("--summary", default="", help="also append a Markdown summary to this file")
    args = parser.parse_args()
    url = args.url.rstrip("/")

    try:
        with open(args.methods, encoding="utf-8") as f:
            methods = json.load(f)["methods"]
    except (OSError, ValueError, KeyError, TypeError) as err:
        print("cannot read " + args.methods + ": " + str(err), file=sys.stderr)
        return 2

    code, body = http_get(url + "/version")
    version = parse(body) if code == 200 else None
    if not isinstance(version, dict) or not version.get("version"):
        print(url + "/version is not reachable (" + (body if code == 0 else "HTTP " + str(code)) + "), nothing written", file=sys.stderr)
        return 1

    previous = load_previous(args.previous)
    generated = now()
    result = {
        "generated": generated,
        "instance": url,
        "version": version.get("version"),
        "did-dri": version.get("did-dri"),
        "methods": [],
    }
    changes = []
    for method in methods:
        published = {key: method[key] for key in ("method", "dif_recommended", "link", "note") if key in method}
        published["dids"] = []
        for did in method.get("dids") or []:
            before = previous.get(did)
            entry = entry_for(did, check(url, did), before, generated)
            if before and before.get("status") != entry["status"]:
                changes.append((did, STATUS_TEXT[before["status"]], STATUS_TEXT[entry["status"]]))
            published["dids"].append(entry)
            print(did + ": " + describe(entry), file=sys.stderr)
        result["methods"].append(published)

    text = json.dumps(result, indent=2, ensure_ascii=False) + "\n"
    if args.output == "-":
        sys.stdout.write(text)
    else:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(text)
    if args.summary:
        with open(args.summary, "a", encoding="utf-8") as f:
            f.write(summary(result, changes, bool(previous)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
