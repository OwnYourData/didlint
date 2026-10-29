// Start page of the Universal Resolver of OwnYourData. Everything comes from
// this host: the page calls the API on the same origin and loads nothing else.
// Values from the API or the visitor are only ever set as text, never as HTML.
(function () {
  "use strict";

  var DIF_RECOMMENDED = ["cid", "ethr", "hedera", "webplus", "webvh"];
  var EXAMPLES = DIF_RECOMMENDED.concat(["oyd"]);
  var DID_LINTER = "https://didlint.ownyourdata.eu/validate?did=";
  var $ = function (id) { return document.getElementById(id); };
  var current = null; // { did, document, result }
  var view = "document";

  // characters of a DID stay as they are, everything else is percent-encoded
  function encodeDid(did) {
    return did.replace(/[^A-Za-z0-9._~:!$&'()*+,;=@\/%-]/g, function (c) { return encodeURIComponent(c); });
  }

  function el(tag, text, attrs) {
    var e = document.createElement(tag);
    if (text !== undefined && text !== null) e.textContent = text;
    if (attrs) Object.keys(attrs).forEach(function (k) { e.setAttribute(k, attrs[k]); });
    return e;
  }

  function pageLink(did) { return "/?did=" + encodeURIComponent(did); }

  // ---------- theme ----------
  function setupTheme() {
    var b = $("theme-toggle"), r = document.documentElement;
    var m = window.matchMedia("(prefers-color-scheme: dark)");
    function system() { return m.matches ? "dark" : "light"; }
    function now() { return r.getAttribute("data-theme") || system(); }
    function show() {
      var dark = now() === "dark";
      b.setAttribute("data-mode", dark ? "dark" : "light");
      b.setAttribute("aria-label", dark ? "Switch to light mode" : "Switch to dark mode");
      b.title = b.getAttribute("aria-label");
    }
    b.addEventListener("click", function () {
      var next = now() === "dark" ? "light" : "dark";
      try {
        if (next === system()) { r.removeAttribute("data-theme"); localStorage.removeItem("uniresolver-theme"); }
        else { r.setAttribute("data-theme", next); localStorage.setItem("uniresolver-theme", next); }
      } catch (e) { r.setAttribute("data-theme", next); }
      show();
    });
    if (m.addEventListener) m.addEventListener("change", show);
    b.hidden = false;
    show();
  }

  // ---------- methods and examples ----------
  function loadMethods() {
    fetch("/1.0/testIdentifiers", { headers: { Accept: "application/json" } })
      .then(function (r) { if (!r.ok) throw new Error("HTTP " + r.status); return r.json(); })
      .then(function (tests) {
        var list = $("method-list"), examples = $("examples");
        list.textContent = "";
        examples.textContent = "Examples: ";
        Object.keys(tests).forEach(function (method) {
          var li = el("li");
          var name = el("div", null, { "class": "method" });
          name.appendChild(el("code", "did:" + method));
          if (DIF_RECOMMENDED.indexOf(method) >= 0) name.appendChild(el("span", "DIF", { "class": "badge", title: "recommended by the Decentralized Identity Foundation" }));
          var dids = el("div", null, { "class": "dids" });
          (tests[method] || []).forEach(function (did) {
            var a = el("a", null, { href: pageLink(did), title: did });
            a.appendChild(el("code", did));
            dids.appendChild(a);
          });
          li.appendChild(name);
          li.appendChild(dids);
          list.appendChild(li);
          if (EXAMPLES.indexOf(method) >= 0 && tests[method] && tests[method][0]) {
            examples.appendChild(el("a", "did:" + method, { href: pageLink(tests[method][0]), title: tests[method][0] }));
          }
        });
      })
      .catch(function () {
        var list = $("method-list");
        list.textContent = "";
        list.appendChild(el("li", "The list of methods is not available right now; /1.0/methods answers it as well."));
        $("examples").textContent = "";
      });
  }

  // ---------- resolution ----------
  function errorText(body) {
    var meta = body && body.didResolutionMetadata;
    var err = meta && meta.error;
    if (!err) return null;
    if (typeof err === "string") return { title: err, detail: meta.errorMessage || "" };
    return { title: err.title || err.type || "error", detail: err.detail || "" };
  }

  function showStatus(kind, title, detail) {
    var s = $("status");
    s.className = "result " + kind;
    s.textContent = "";
    s.appendChild(el("strong", title));
    if (detail) s.appendChild(el("p", detail, { "class": "detail" }));
  }

  function render() {
    if (!current) return;
    var data = view === "document" ? current.document : current.result;
    $("output").textContent = JSON.stringify(data, null, 2);
    $("tab-document").setAttribute("aria-selected", view === "document" ? "true" : "false");
    $("tab-result").setAttribute("aria-selected", view === "result" ? "true" : "false");
  }

  function resolve(did) {
    did = did.trim();
    if (!did) return;
    var url = "/1.0/identifiers/" + encodeDid(did);
    var started = Date.now();
    current = null;
    $("result").hidden = false;
    $("toolbar").hidden = true;
    $("output-box").hidden = true;
    showStatus("", "Resolving " + did + " …");
    fetch(url, { headers: { Accept: "application/did-resolution" } })
      .then(function (r) {
        return r.text().then(function (text) {
          var body = null;
          try { body = JSON.parse(text); } catch (e) { body = null; }
          return { status: r.status, body: body };
        });
      })
      .then(function (res) {
        var ms = Date.now() - started;
        var body = res.body;
        var method = (did.split(":")[1] || "").toLowerCase();
        if (body && body.didDocument) {
          var meta = body.didDocumentMetadata || {};
          if (meta.deactivated === true) showStatus("warning", "Resolved, the DID is deactivated", did + " · " + ms + " ms");
          else showStatus("success", "Resolved", did + " · " + ms + " ms");
          current = { did: did, document: body.didDocument, result: body };
          $("lint").href = DID_LINTER + encodeURIComponent(did);
          $("raw").href = url;
          $("toolbar").hidden = false;
          $("output-box").hidden = false;
          view = "document";
          render();
          return;
        }
        var err = errorText(body);
        if (res.status === 501) {
          showStatus("warning", "did:" + method + " is not supported by this resolver", "The supported methods are listed below.");
        } else if (res.status === 503 && !body) {
          showStatus("warning", "Too many requests", "The resolver answers at most 300 requests per minute; please try again in a minute.");
        } else if (err) {
          showStatus("danger", "Not resolved: " + err.title, err.detail);
        } else {
          showStatus("danger", "Not resolved", "The resolver answered with HTTP " + res.status + ".");
        }
        if (body) {
          current = { did: did, document: body, result: body };
          view = "result";
          $("output-box").hidden = false;
          render();
        }
      })
      .catch(function () {
        showStatus("danger", "The resolver could not be reached", "Please try again later.");
      });
  }

  function setupForm() {
    $("form").addEventListener("submit", function (ev) {
      ev.preventDefault();
      var did = $("did").value.trim();
      if (!did) return;
      try { history.pushState(null, "", pageLink(did)); } catch (e) {}
      resolve(did);
    });
    $("tab-document").addEventListener("click", function () { view = "document"; render(); });
    $("tab-result").addEventListener("click", function () { view = "result"; render(); });
    $("copy").addEventListener("click", function () {
      var b = this;
      var text = $("output").textContent;
      var done = function () { b.textContent = "Copied"; setTimeout(function () { b.textContent = "Copy"; }, 1500); };
      if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(text).then(done, function () {});
    });
    window.addEventListener("popstate", fromLocation);
  }

  function fromLocation() {
    var did = new URLSearchParams(window.location.search).get("did");
    if (did) { $("did").value = did; resolve(did); }
  }

  setupTheme();
  setupForm();
  loadMethods();
  fromLocation();
})();
