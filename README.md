Kubernetes Mutating Admission Webhook
Namespace Label Injection & Pod Scheduling Enforcement

This project implements a Mutating Admission Webhook that automatically injects Namespace labels into Pods and Deployments at creation time.

The goal is simple and strict:

Namespaces define policy

Pods inherit labels automatically

Scheduling is controlled centrally

Developers do not manage platform labels

Why This Exists

In real clusters:

Teams forget labels

Labels drift

Scheduling rules break silently

Cost, security, and ownership tracking become unreliable

This webhook eliminates human error by enforcing labels at admission time, before objects are stored in etcd.

High-Level Flow

What happens internally:

Namespace is labeled (e.g. team=testing, env=prod)

Pod / Deployment creation request hits API Server

Mutating Webhook intercepts the request

Namespace labels are injected into the Pod spec

Scheduler places the Pod based on injected labels

No controllers.
No sidecars.
No runtime overhead.

Prerequisites

Kubernetes cluster (kubeadm)

Access to control-plane node

Docker + containerd

OpenSSL

kubectl

Step 1: Enable Admission Webhooks

Edit the API server manifest:

vi /etc/kubernetes/manifests/kube-apiserver.yaml


Update the admission plugins:

--enable-admission-plugins=NodeRestriction,MutatingAdmissionWebhook,ValidatingAdmissionWebhook


Important:
If this flag is missing, the webhook will never be invoked.
Kubernetes will not warn you.

Step 2: Generate TLS Certificate (SAN Required)
Create SAN Configuration
cat > san.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = webhook-service.webhook-system.svc

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = webhook-service
DNS.2 = webhook-service.webhook-system
DNS.3 = webhook-service.webhook-system.svc
EOF

Generate Key and Certificate
openssl genrsa -out tls.key 2048

openssl req -new -key tls.key -out tls.csr -config san.cnf

openssl x509 -req -in tls.csr -signkey tls.key \
  -out tls.crt -days 365 \
  -extensions v3_req -extfile san.cnf


Note:
SAN is mandatory.
CN-only certificates will fail silently.

Step 3: Create Kubernetes TLS Secret
kubectl delete secret webhook-tls -n webhook-system --ignore-not-found

kubectl create secret tls webhook-tls \
  --cert=tls.crt \
  --key=tls.key \
  -n webhook-system

Step 4: Build and Push Webhook Image
Build Image
docker build -t manoharshetty507/webhook:v3 .

Import into containerd
ctr -n k8s.io images import <(docker save manoharshetty507/webhook:v3)

Push to Registry
docker push manoharshetty507/webhook:v3

Step 5: Apply Webhook Manifests
Encode Certificate
base64 -w0 tls.crt

Apply Resources
kubectl apply -f webhook-configuration.yaml
kubectl apply -f webhook-deployment.yaml

Verify
kubectl get mutatingwebhookconfigurations

Step 6: Enable Webhook per Namespace

The webhook runs only if the namespace has this label:

ns-label-sync=enabled

Example: Default Namespace
kubectl label namespace default ns-label-sync=enabled --overwrite
kubectl label namespace default env=from-ns --overwrite
kubectl label namespace default team=devops --overwrite

Test Pod
kubectl apply -f testing-pod.yaml
kubectl get pod test-pod -n default --show-labels


Result:
Pod automatically inherits namespace labels.

Step 7: Full Scheduling Test
Create Testing Namespace
kubectl create namespace testing

* Label Namespace
```
kubectl label namespace testing \
  ns-label-sync=enabled \
  env=testing \
  team=testing \
  --overwrite
```
* Show Namespace labels
```
kubectl get namespace testing --show-labels
```
Deploy Application
```
kubectl create deployment nginx --image=nginx -n testing
```
```
kubectl get pods -n testing --show-labels
```

Confirm Label Injection
```
kubectl get pod -n testing -o jsonpath='{.items[0].metadata.labels}'
```
Step 8: Pod Scheduling Validation
Apply Test Pod
```
kubectl apply -f testing-pod.yaml
```

Expected State:
* Pod remains Pending (no matching node labels).

Label Node
```
kubectl label node master01 team=testing
```

Result:
* Pod schedules immediately.

Key Design Principles
Namespace is the source of truth
Developers do not control platform labels
Scheduling rules are enforced centrally
Admission-time mutation is the cleanest control point

No reconciliation loops.
No runtime hacks.
No surprises.

Common Failure Points
Admission plugins not enabled
Wrong SAN in certificate
Incorrect CA bundle in webhook config
Service DNS mismatch
Admission webhooks fail silently.
Always check logs.

License
MIT

License

MIT
