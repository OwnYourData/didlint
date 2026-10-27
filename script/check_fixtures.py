#!/usr/bin/env python3
"""Regression checks for DID Lint.

Two independent checks, both driven by the fixtures in pytest/ and the
expectations in pytest/expectations.json:

  --url URL          Runs the fixtures against a DID Lint instance and
                     compares every response with NN_output/. Also checks
                     that /version reports the structure pinned in
                     config/initializers/constants.rb and that did:oyd
                     resolution returns the requested DID as id.
                     With --offline the instance must run in offline mode:
                     every request that has to resolve a DID is expected to
                     be rejected with HTTP 503.

  --structure [DRI]  Validates the fixtures directly against a SOyA
                     structure through soya-web-cli and compares the
                     verdict with expectations.json. Run this for a
                     candidate structure before switching SOYA_DID_DRI.
                     Without DRI the pinned structure is checked. If soya/
                     holds a local copy of the structure, it must equal the
                     published one.

Exit code 0 if everything matches, 1 on any mismatch, 2 on usage errors.
Only the Python standard library is used.
"""

import argparse
import glob
import json
import os
import re
import signal
import sys
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIXTURES = os.path.join(ROOT, "pytest")
CONSTANTS = os.path.join(ROOT, "config", "initializers", "constants.rb")
STRUCTURES = os.path.join(ROOT, "soya")
OFFLINE_ERROR = "resolving DIDs is not available in offline mode"
TIMEOUT = 60


def http(method, url, body=None, headers=None):
    data = body.encode("utf-8") if isinstance(body, str) else body
    req = urllib.request.Request(url, data=data, method=method, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            return resp.status, resp.headers, resp.read().decode("utf-8")
    except urllib.error.HTTPError as err:
        return err.code, err.headers, err.read().decode("utf-8")
    except (urllib.error.URLError, OSError) as err:
        # not reachable: status 0, the reason as body
        return 0, None, str(getattr(err, "reason", err))


def constant(name):
    with open(CONSTANTS, encoding="utf-8") as f:
        match = re.search(r'^%s\s*=\s*"([^"]*)"' % re.escape(name), f.read(), re.M)
    if not match:
        sys.exit("cannot read %s from %s" % (name, CONSTANTS))
    return match.group(1)


def load_expectations():
    with open(os.path.join(FIXTURES, "expectations.json"), encoding="utf-8") as f:
        return json.load(f)


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def fixture_name(path):
    return os.path.relpath(path, FIXTURES)


class Report:
    def __init__(self, title):
        self.title = title
        self.failed = 0
        self.passed = 0
        self.known = 0

    def ok(self, name, note=""):
        self.passed += 1
        print("PASS  %s%s" % (name, ("  " + note) if note else ""))

    def fail(self, name, detail):
        self.failed += 1
        print("FAIL  %s  %s" % (name, detail))

    def xfail(self, name, reason):
        self.known += 1
        print("XFAIL %s  (%s)" % (name, reason))

    def summary(self):
        print("%s: %d passed, %d failed, %d known failures" % (self.title, self.passed, self.failed, self.known))
        return self.failed == 0


def check_offline_rejection(rep, name, status, body):
    try:
        error = json.loads(body).get("error")
    except (ValueError, AttributeError):
        error = None
    if status == 503 and error == OFFLINE_ERROR:
        rep.ok(name, "rejected offline")
    else:
        rep.fail(name, "expected HTTP 503 '%s', got HTTP %s %s" % (OFFLINE_ERROR, status, body.strip()[:120]))


def check_instance(base, allow_any_dri, offline=False):
    base = base.rstrip("/")
    exp = load_expectations()
    known = exp.get("instance", {}).get("known_failures", {})
    rep = Report("instance " + base)

    status, _, body = http("GET", base + "/version")
    try:
        version = json.loads(body)
    except ValueError:
        version = {}
    if status == 0:
        rep.fail("/version", "instance not reachable: %s" % body)
        return rep.summary()
    if status != 200 or not version:
        rep.fail("/version", "HTTP %s" % status)
    else:
        pinned = constant("SOYA_DID_DRI")
        mode = "offline" if offline else "online"
        if version.get("mode", "online") != mode:
            rep.fail("/version", "mode %s, expected %s" % (version.get("mode", "online"), mode))
        elif version.get("did-dri") == pinned or allow_any_dri:
            rep.ok("/version", "version %s, %s, did-dri %s" % (version.get("version"), mode, version.get("did-dri")))
        else:
            rep.fail("/version", "did-dri %s differs from the pinned %s" % (version.get("did-dri"), pinned))

    check_web(base, rep)

    cases = []
    for path in sorted(glob.glob(os.path.join(FIXTURES, "01_input", "*.doc"))):
        did = read(path).strip()
        if offline:
            status, _, body = http("GET", base + "/api/validate/" + did)
            check_offline_rejection(rep, fixture_name(path), status, body)
            continue
        cases.append((path, lambda did=did: http("GET", base + "/api/validate/" + did)))
    for group in ("02_input", "03_input"):
        for path in sorted(glob.glob(os.path.join(FIXTURES, group, "*.json"))):
            payload = read(path)
            cases.append((path, lambda payload=payload: http(
                "POST", base + "/api/validate", payload, {"Content-Type": "application/json"})))

    for path, call in cases:
        name = fixture_name(path)
        expected = read(path.replace("_input" + os.sep, "_output" + os.sep)).strip()
        _, _, body = call()
        matches = body.strip() == expected
        if name in known:
            if matches:
                rep.fail(name, "listed as known failure but passes; remove it from expectations.json")
            else:
                rep.xfail(name, known[name])
        elif matches:
            rep.ok(name)
        else:
            rep.fail(name, "expected %s, got %s" % (expected, body.strip()))

    for did in exp.get("resolve", []):
        status, headers, body = http("GET", base + "/api/resolve/" + did)
        if offline:
            check_offline_rejection(rep, "resolve " + did, status, body)
            continue
        via = headers.get("X-DID-Resolved-Via", "-") if headers else "-"
        try:
            got = json.loads(body).get("id")
        except (ValueError, AttributeError):
            got = None
        if status == 200 and got == did:
            rep.ok("resolve " + did, "via " + via)
        else:
            rep.fail("resolve " + did, "HTTP %s, id %s, via %s" % (status, got, via))

    return rep.summary()


def check_web(base, rep):
    # the web frontend and its precompiled assets, and the API documentation
    status, _, body = http("GET", base + "/")
    if status != 200:
        rep.fail("web /", "HTTP %s" % status)
        return
    rep.ok("web /")
    assets = []
    for tag in re.findall(r"<link\b[^>]*>", body):
        href = re.search(r'href="([^"]+)"', tag)
        if 'rel="stylesheet"' in tag and href and href.group(1).startswith("/"):
            assets.append(href.group(1))
    assets += [src for src in re.findall(r'<script\b[^>]*src="([^"]+)"', body) if src.startswith("/")]
    if not assets:
        rep.fail("web assets", "the start page references no local stylesheet or script")
    for asset in assets:
        status, _, _ = http("GET", base + asset)
        if status == 200:
            rep.ok("web " + asset)
        else:
            rep.fail("web " + asset, "HTTP %s" % status)
    status, _, _ = http("GET", base + "/api-docs/index.html")
    if status == 200:
        rep.ok("web /api-docs")
    else:
        rep.fail("web /api-docs", "HTTP %s" % status)
    status, _, body = http("GET", base + "/api-docs/v1/swagger.yaml")
    if status == 200 and "/api/resolve/{did}" in body:
        rep.ok("web /api-docs/v1/swagger.yaml")
    else:
        rep.fail("web /api-docs/v1/swagger.yaml", "HTTP %s, or the resolve endpoint is not documented" % status)


def load_structure(repo, dri):
    status, _, body = http("GET", repo.rstrip("/") + "/" + dri)
    if status != 200:
        sys.exit("cannot load structure %s from %s (HTTP %s)" % (dri, repo, status))
    return json.loads(body)


def uses_lists(structure):
    # mirrors Structure.list_attributes in app/services/did_lint/structure.rb:
    # structures compiled with soya-js 0.8.10 or later validate sets as rdf:List
    return any(node.get("@type") == "OverlayValidation" and "rdf:rest" in json.dumps(node)
               for node in structure.get("@graph", []))


def set_attributes(structure):
    attrs = []
    for node in structure.get("@graph", []):
        domain = node.get("domain")
        domains = domain if isinstance(domain, list) else [domain]
        if node.get("soya:containerType") == "set" and "Did" in domains:
            attrs.append(node.get("@id"))
    return sorted(a for a in attrs if a)


def prepare(document, repo, dri, list_attrs):
    # mirrors soya_prep in app/services/did_lint/linter.rb
    base = repo.rstrip("/") + "/" + dri + "/"
    context = {"@version": 1.1, "did": base, "@vocab": base}
    for attr in list_attrs:
        context[attr] = {"@container": "@list"}
    doc = dict(document)
    doc.pop("@context", None)
    doc["@type"] = "Did"
    return {"@context": context, "@graph": [doc]}


def check_local_copy(rep, repo, dri):
    # the copy in soya/ (fallback and offline mode) must be the published structure
    path = os.path.join(STRUCTURES, dri + ".json")
    if not os.path.exists(path):
        if dri == constant("SOYA_DID_DRI"):
            rep.fail("soya/" + dri + ".json", "no local copy of the pinned structure")
        else:
            print("NOTE  no local copy of %s in soya/" % dri)
        return
    status, _, body = http("GET", repo.rstrip("/") + "/" + dri)
    try:
        same = status == 200 and json.loads(body) == json.loads(read(path))
    except ValueError:
        same = False
    if same:
        rep.ok("soya/" + dri + ".json", "equals the published structure")
    else:
        rep.fail("soya/" + dri + ".json", "differs from the published structure (HTTP %s)" % status)


def check_structure(dri, encoding, soya_web_cli, repo):
    exp = load_expectations()["structure"]
    expected = exp["valid"]
    dri = dri or constant("SOYA_DID_DRI")
    structure = load_structure(repo, dri)
    if encoding == "auto":
        encoding = "list" if uses_lists(structure) else "flat"
    rep = Report("structure %s (%s encoding)" % (dri, encoding))
    if dri != exp.get("dri"):
        print("NOTE  expectations were recorded for %s" % exp.get("dri"))
    check_local_copy(rep, repo, dri)
    list_attrs = set_attributes(structure) if encoding == "list" else []

    on_disk = sorted(fixture_name(p) for g in ("02_input", "03_input")
                     for p in glob.glob(os.path.join(FIXTURES, g, "*.json")))
    for name in on_disk:
        if name not in expected:
            rep.fail(name, "no expectation in expectations.json")
            continue
        document = json.loads(read(os.path.join(FIXTURES, name)))
        payload = json.dumps(prepare(document, repo, dri, list_attrs))
        status, _, body = http("POST", soya_web_cli.rstrip("/") + "/api/v1/validate/" + dri,
                               payload, {"Content-Type": "application/json"})
        try:
            got = json.loads(body).get("isValid")
        except (ValueError, AttributeError):
            got = None
        if status != 200 or got is None:
            rep.fail(name, "HTTP %s from soya-web-cli" % status)
        elif got == expected[name]:
            rep.ok(name, "valid" if got else "invalid")
        else:
            rep.fail(name, "expected %s, got %s" % ("valid" if expected[name] else "invalid",
                                                    "valid" if got else "invalid"))
    for name in sorted(set(expected) - set(on_disk)):
        rep.fail(name, "expectation without fixture")
    return rep.summary()


def main():
    if hasattr(signal, "SIGPIPE"):
        signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--url", help="base URL of a DID Lint instance")
    parser.add_argument("--allow-any-dri", action="store_true",
                        help="do not require the instance to run the pinned structure")
    parser.add_argument("--offline", action="store_true",
                        help="the instance runs with DIDLINT_OFFLINE=true")
    parser.add_argument("--structure", nargs="?", const="", default=None, metavar="DRI",
                        help="check a SOyA structure; default is the pinned one")
    parser.add_argument("--encoding", choices=("auto", "flat", "list"), default=None,
                        help="how set values are encoded; auto decides from the structure; default from expectations.json")
    parser.add_argument("--soya-web-cli", default=os.environ.get("SOYA_WEB_CLI") or constant("SOYA_WEB_CLI"))
    parser.add_argument("--soya-repo", default=os.environ.get("SOYA_REPO") or constant("SOYA_REPO"))
    args = parser.parse_args()
    if args.url is None and args.structure is None:
        parser.print_usage()
        return 2

    ok = True
    if args.structure is not None:
        encoding = args.encoding or load_expectations()["structure"].get("encoding", "flat")
        ok = check_structure(args.structure, encoding, args.soya_web_cli, args.soya_repo) and ok
    if args.url is not None:
        ok = check_instance(args.url, args.allow_any_dri, args.offline) and ok
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
