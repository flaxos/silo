#!/usr/bin/env python3
"""
tools/test_mobile_server.py — Automated E2E verification of SILO Operations Web Server
Verifies HTTP endpoints, static asset delivery, and remote mobile UAT capabilities.
"""

import json
import subprocess
import sys
import time
import urllib.error
import urllib.request

PORT = 8093
BASE_URL = f"http://127.0.0.1:{PORT}"

def http_get(path: str):
    url = f"{BASE_URL}{path}"
    req = urllib.request.Request(url, headers={"User-Agent": "SILO-Mobile-UAT-Test/1.0"})
    with urllib.request.urlopen(req, timeout=5) as response:
        status = response.status
        headers = dict(response.getheaders())
        body = response.read().decode("utf-8")
        return status, headers, body

def http_post(path: str, data: dict = None):
    url = f"{BASE_URL}{path}"
    json_bytes = json.dumps(data or {}).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=json_bytes,
        headers={"Content-Type": "application/json", "User-Agent": "SILO-Mobile-UAT-Test/1.0"},
        method="POST"
    )
    with urllib.request.urlopen(req, timeout=5) as response:
        status = response.status
        headers = dict(response.getheaders())
        body = response.read().decode("utf-8")
        return status, headers, body

def main():
    print(f"=== Starting SILO Server on port {PORT} ===")
    proc = subprocess.Popen(
        ["godot", "--headless", "-s", "tools/observer_server.gd", "--", f"--port={PORT}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True
    )

    # Wait for server readiness
    ready = False
    for i in range(30):
        try:
            status, _, _ = http_get("/api/overview")
            if status == 200:
                ready = True
                print(f"Server is ready after ~{i * 0.5:.1f}s")
                break
        except Exception:
            time.sleep(0.5)

    if not ready:
        print("[FAIL] Server failed to start or become ready in 15 seconds.")
        proc.terminate()
        sys.exit(1)

    passed = 0
    failed = 0

    def assert_test(name: str, condition: bool, detail: str = ""):
        nonlocal passed, failed
        if condition:
            passed += 1
            print(f"  ✓ {name}")
        else:
            failed += 1
            print(f"  ✗ {name}: {detail}")

    try:
        print("\n--- Testing Mobile Static Web Assets ---")
        # Test GET / (index.html)
        status, headers, html = http_get("/")
        assert_test("GET / returns 200 OK", status == 200)
        assert_test("Viewport meta tag configured for mobile", 'name="viewport"' in html and 'user-scalable=no' in html)
        assert_test("Operations stylesheet linked", 'operations.css' in html)
        assert_test("Operations controller script linked", 'operations.js' in html)
        assert_test("Operations Console tab in HTML", 'id="tab-operations"' in html)
        assert_test("Mobile thumb-friendly bottom navigation present", 'id="mobile-nav"' in html)
        assert_test("Directive console container present", 'class="ops-directive-box"' in html)

        # Test GET /operations.css
        status, headers, css = http_get("/operations.css")
        assert_test("GET /operations.css returns 200 OK", status == 200)
        assert_test("operations.css has responsive @media query", "@media (max-width: 768px)" in css)
        assert_test("operations.css contains terminal styling", ".ops-directive-box" in css)

        # Test GET /operations.js
        status, headers, js = http_get("/operations.js")
        assert_test("GET /operations.js returns 200 OK", status == 200)
        assert_test("operations.js contains brief fetcher", "fetchBrief" in js)
        assert_test("operations.js contains directive dispatcher", "handleDispatch" in js)
        assert_test("operations.js contains map focus bridge", "handleLocateInSilo" in js)

        print("\n--- Testing Operations REST API ---")
        # Test GET /api/operations/brief
        status, _, body = http_get("/api/operations/brief")
        assert_test("GET /api/operations/brief returns 200 OK", status == 200)
        brief = json.loads(body)
        assert_test("Brief contains 'active' array", isinstance(brief.get("active"), list))
        assert_test("Brief contains 'active_count'", "active_count" in brief)

        # Test GET /api/operations/detail
        status, _, body = http_get("/api/operations/detail")
        assert_test("GET /api/operations/detail returns 200 OK", status == 200)
        detail = json.loads(body)
        # If there are active cases, check detail fields
        if brief.get("active"):
            first_id = brief["active"][0]["id"]
            status, _, body = http_get(f"/api/operations/detail?id={first_id}")
            detail = json.loads(body)
            assert_test("Case detail has id and title", "id" in detail and "title" in detail)
            assert_test("Case detail has OS telemetry", "os_telemetry" in detail)
            assert_test("Case detail has available_actions", isinstance(detail.get("available_actions"), list))
        else:
            print("  - Note: No active cases on fresh tick 0 (expected before wear/incidents)")

        # Test POST /api/operations/action validation
        try:
            http_post("/api/operations/action", {})
            assert_test("POST /api/operations/action missing params returns 400", False, "Expected 400 error")
        except urllib.error.HTTPError as e:
            assert_test("POST /api/operations/action missing params returns 400", e.code == 400)

        # Test POST /api/step with operations brief in response
        status, _, body = http_post("/api/step", {"ticks": 6})
        assert_test("POST /api/step returns 200 OK", status == 200)
        step_res = json.loads(body)
        assert_test("Simulation advanced ticks", step_res.get("current_tick") == 6)
        assert_test("Step response includes operations_brief", "operations_brief" in step_res)

        # Step 12 more ticks to reach tick 18 where pump wear triggers an active case
        status, _, body = http_post("/api/step", {"ticks": 12})
        assert_test("Step to tick 18 succeeds", status == 200)
        status, _, body = http_get("/api/operations/brief")
        brief = json.loads(body)
        assert_test("Active case generated at tick 18", brief.get("active_count", 0) >= 1)

        if brief.get("active"):
            cid = brief["active"][0]["id"]
            status, _, body = http_get(f"/api/operations/detail?id={cid}")
            assert_test(f"GET /api/operations/detail?id={cid} returns 200", status == 200)
            detail = json.loads(body)
            assert_test("Case detail has structured briefing", "briefing" in detail)
            briefing = detail.get("briefing", {})
            assert_test("Briefing has whats_happening", bool(briefing.get("whats_happening")))
            assert_test("Briefing has why_it_matters", bool(briefing.get("why_it_matters")))
            assert_test("Briefing has player_authority", bool(briefing.get("player_authority")))
            assert_test("Case has available_actions", len(detail.get("available_actions", [])) > 0)

            # Test dispatching directive via POST
            act_id = detail["available_actions"][0]["id"]
            status, _, body = http_post("/api/operations/action", {"case_id": cid, "action": act_id})
            assert_test(f"POST /api/operations/action ({act_id}) returns 200", status == 200)
            act_res = json.loads(body)
            assert_test("Action dispatch reported success", act_res.get("success") is True)

        # Test POST /api/operations/save & load
        status, _, body = http_post("/api/operations/save", {"path": "/tmp/test_mobile_silo.save"})
        assert_test("POST /api/operations/save returns 200 OK", status == 200)
        save_res = json.loads(body)
        assert_test("Save reported success", save_res.get("success") is True)

        status, _, body = http_post("/api/operations/load", {"path": "/tmp/test_mobile_silo.save"})
        assert_test("POST /api/operations/load returns 200 OK", status == 200)
        load_res = json.loads(body)
        assert_test("Load restored saved tick 18", load_res.get("current_tick") == 18)

    finally:
        print("\n=== Shutting down server ===")
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()

    print(f"\nMobile Operations Test Results: {passed} PASSED, {failed} FAILED")
    if failed > 0:
        sys.exit(1)
    else:
        print("All mobile server verification checks passed successfully!")

if __name__ == "__main__":
    main()
