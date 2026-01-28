import json
import base64
from flask import Flask, request, jsonify
from kubernetes import client, config

app = Flask(__name__)
config.load_incluster_config()

def esc(k):
    return k.replace("~", "~0").replace("/", "~1")

@app.route("/mutate", methods=["POST"])
def mutate():
    review = request.get_json(silent=True)
    if not review or "request" not in review:
        return allow()

    req = review["request"]
    uid = req.get("uid")
    namespace = req.get("namespace")
    kind = req.get("kind", {}).get("kind")

    # 🔥 THIS MUST BE Pod
    if kind != "Pod" or not namespace:
        return allow(uid)

    v1 = client.CoreV1Api()
    ns_labels = v1.read_namespace(namespace).metadata.labels or {}

    patch = []
    for k, v in ns_labels.items():
        patch.append({
            "op": "add",
            "path": "/metadata/labels/" + esc(k),
            "value": v
        })

    if not patch:
        return allow(uid)

    return jsonify({
        "apiVersion": "admission.k8s.io/v1",
        "kind": "AdmissionReview",
        "response": {
            "uid": uid,
            "allowed": True,
            "patchType": "JSONPatch",
            "patch": base64.b64encode(json.dumps(patch).encode()).decode()
        }
    })

def allow(uid=None):
    return jsonify({
        "apiVersion": "admission.k8s.io/v1",
        "kind": "AdmissionReview",
        "response": {
            "uid": uid,
            "allowed": True
        }
    })

if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=8443,
        ssl_context=("/tls/tls.crt", "/tls/tls.key")
    )
