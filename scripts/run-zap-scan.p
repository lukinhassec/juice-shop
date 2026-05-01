import requests, time, os, json, sys

ZAP = os.getenv("ZAP_URL", "http://localhost:8080")
KEY = os.getenv("ZAP_API_KEY", "zapkey123")
TARGET = os.getenv("TARGET_URL", "http://localhost:3000")

def zap(endpoint, params={}):
    params["apikey"] = KEY
    try:
        r = requests.get(f"{ZAP}/JSON/{endpoint}", params=params, timeout=30)
        return r.json()
    except Exception as e:
        print(f"ZAP API error on {endpoint}: {e}")
        sys.exit(1)

def wait_for_scan(scan_type, scan_id=None):
    print(f"  Polling {scan_type}...")
    while True:
        if scan_type == "ajaxSpider":
            status = zap("ajaxSpider/view/status")["status"]
            print(f"  [{scan_type}] status: {status}")
            if status == "stopped":
                return
        else:
            endpoint = "spider/view/status" if scan_type == "spider" else "ascan/view/status"
            status = zap(endpoint, {"scanId": scan_id})["status"]
            print(f"  [{scan_type}] progress: {status}%")
            if str(status) == "100":
                return
        time.sleep(15)

print(f"Target: {TARGET}")

print("\n=== Spider ===")
r = zap("spider/action/scan", {"url": TARGET, "recurse": "true"})
wait_for_scan("spider", r["scan"])

print("\n=== Ajax Spider ===")
zap("ajaxSpider/action/scan", {"url": TARGET})
wait_for_scan("ajaxSpider")

print("\n=== Active Scan ===")
r = zap("ascan/action/scan", {"url": TARGET, "recurse": "true"})
wait_for_scan("ascan", r["scan"])

print("\n=== Collecting Alerts ===")
alerts = zap("alert/view/alerts", {"baseurl": TARGET, "count": "500"})
total = len(alerts.get("alerts", []))
print(f"Total alerts: {total}")

os.makedirs("reports", exist_ok=True)

with open("reports/zap_raw.json", "w") as f:
    json.dump(alerts, f, indent=2)

# Resumo por severidade no terminal
severity_count = {}
for a in alerts.get("alerts", []):
    sev = a.get("riskdesc", "Unknown")
    severity_count[sev] = severity_count.get(sev, 0) + 1

print("\n=== Summary ===")
for sev, count in sorted(severity_count.items()):
    print(f"  {sev}: {count}")

print("\nDone. Report saved to reports/zap_raw.json")
