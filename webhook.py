import json
import base64
from flask import Flask, request, jsonify
from kubernetes import client, config

app = Flask(__name__)

# Load Kubernetes configuration
config.load_incluster_config()  # Use inside cluster
# config.load_kube_config()  # Uncomment for local testing

@app.route("/mutate", methods=["POST"])
def mutate():
    request_data = request.get_json()
    req = request_data["request"]
    namespace = req["namespace"]
    workload = req["object"]

    # Workload types to mutate
    valid_kinds = {"Deployment", "StatefulSet", "DaemonSet", "Pod"}

    if req["kind"]["kind"] not in valid_kinds:
        return admission_response(req, [])  # No mutation needed

    # Get namespace labels
    v1 = client.CoreV1Api()
    ns = v1.read_namespace(namespace)
    ns_labels = ns.metadata.labels or {}

    # Inject namespace labels into workload
    if "metadata" not in workload:
        workload["metadata"] = {}

    if "labels" not in workload["metadata"]:
        workload["metadata"]["labels"] = {}

    workload["metadata"]["labels"].update(ns_labels)

    # Create patch operation
    patch = [{"op": "add", "path": "/metadata/labels", "value": workload["metadata"]["labels"]}]
    return admission_response(req, patch)

def admission_response(req, patch):
    """Builds the Kubernetes admission response"""
    response = {
        "apiVersion": "admission.k8s.io/v1",
        "kind": "AdmissionReview",
        "response": {
            "uid": req["uid"],
            "allowed": True,
            "patchType": "JSONPatch",
            "patch": base64.b64encode(json.dumps(patch).encode()).decode()
        }
    }
    return jsonify(response)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=443, ssl_context=("/tls/tls.crt", "/tls/tls.key"))
