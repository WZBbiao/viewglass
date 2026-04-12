import json, sys

apps_json_str = sys.argv[1]
session = sys.argv[2]

is_real = 'false'
if apps_json_str:
    try:
        apps = json.loads(apps_json_str)
        for a in apps:
            port = str(a.get('port', ''))
            bundle = a.get('bundleIdentifier', '')
            session_id = f"{bundle}@{port}"
            if session_id == session or str(port) == session:
                if a.get('deviceType') == 'device':
                    is_real = 'true'
                break
    except Exception:
        pass

print(is_real)
