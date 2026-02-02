Kubernetes Mutating Admission Webhook
Namespace Label Injection & Pod Scheduling Enforcement

This project implements a Mutating Admission Webhook that automatically injects Namespace labels into Pods and Deployments at creation time.

* The goal is simple and strict:
Namespaces define policy
Pods inherit labels automatically
Scheduling is controlled centrally
Developers do not manage platform labels

* Why This Exists
In real clusters:
Teams forget labels
Labels drift
Scheduling rules break silently

Cost, security, and ownership tracking become unreliable

This webhook eliminates human error by enforcing labels at admission time, before objects are stored in etcd.

* High-Level Flow

What happens internally:
Namespace is labeled (e.g. team=testing, env=prod)
Pod / Deployment creation request hits API Server
Mutating Webhook intercepts the request
Namespace labels are injected into the Pod spec
Scheduler places the Pod based on injected labels
No controllers.
No sidecars.
No runtime overhead.

* Prerequisites
Kubernetes cluster 
Access to control-plane node
Docker + containerd
OpenSSL
kubectl

*Step 1: Enable Admission Webhooks

Edit the API server manifest:
vi /etc/kubernetes/manifests/kube-apiserver.yaml
Update the admission plugins:
```
--enable-admission-plugins=NodeRestriction,MutatingAdmissionWebhook,ValidatingAdmissionWebhook
```

Important:
If this flag is missing, the webhook will never be invoked.
Kubernetes will not warn you.

* Step 2: Generate TLS Certificate (SAN Required)
Create SAN Configuration
```
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
```
* Generate Key and Certificate
```
openssl genrsa -out tls.key 2048

openssl req -new -key tls.key -out tls.csr -config san.cnf

openssl x509 -req -in tls.csr -signkey tls.key \
  -out tls.crt -days 365 \
  -extensions v3_req -extfile san.cnf
```

Note:
SAN is mandatory.
CN-only certificates will fail silently.

* Step 3: Create Kubernetes TLS Secret
```
kubectl create secret tls webhook-tls \
  --cert=tls.crt \
  --key=tls.key \
  -n webhook-system
```
* Step 4: Build and Push Webhook Image
Build Image
```
docker build -t manoharshetty507/webhook:v3 .
```
Import into containerd
```
ctr -n k8s.io images import <(docker save manoharshetty507/webhook:v3)
```
Push to Registry
```
docker push manoharshetty507/webhook:v3
```
* Step 5: Apply Webhook Manifests

* Create  Resources
vi webhook-deployment.yaml
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ns-label-webhook
  namespace: webhook-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webhook
  template:
    metadata:
      labels:
        app: webhook
    spec:
      serviceAccountName: webhook-sa
      containers:
      - name: webhook
        image: manoharshetty507/webhook:v1
        ports:
        - containerPort: 8443
        volumeMounts:
        - name: tls
          mountPath: /tls
          readOnly: true
      volumes:
      - name: tls
        secret:
          secretName: webhook-tls
---
apiVersion: v1
kind: Service
metadata:
  name: webhook-service
  namespace: webhook-system
spec:
  ports:
  - port: 443
    targetPort: 8443
  selector:
    app: webhook
```
* Apply the deployment
```
kubectl apply -f webhook-deployment.yaml
```
Encode Certificate
```
base64 -w0 tls.crt
```
Verify


* Create mutating webhook resources
* * Note: Be sure to change caBundle with your encoded certificate.
vi webhook-configurations.yaml
```
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  name: ns-label-webhook
webhooks:
- name: ns-label-webhook.webhook-system.svc
  admissionReviewVersions: ["v1"]
  sideEffects: None
  failurePolicy: Ignore
  timeoutSeconds: 5
  clientConfig:
    service:
      name: webhook-service
      namespace: webhook-system
      path: /mutate
      port: 443
    caBundle: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURqVENDQW5XZ0F3SUJBZ0lVU3NoeURzZFJSUjNDTXA0VG9XMDFaYU5Ub0VVd0RRWUpLb1pJaHZjTkFRRUwKQlFBd0xURXJNQ2tHQTFVRUF3d2lkMlZpYUc5dmF5MXpaWEoyYVdObExuZGxZbWh2YjJzdGMzbHpkR1Z0TG5OMgpZekFlRncweU5qQXhNamt3T1RVMU16VmFGdzB5TnpBeE1qa3dPVFUxTXpWYU1DMHhLekFwQmdOVkJBTU1JbmRsClltaHZiMnN0YzJWeWRtbGpaUzUzWldKb2IyOXJMWE41YzNSbGJTNXpkbU13Z2dFaU1BMEdDU3FHU0liM0RRRUIKQVFVQUE0SUJEd0F3Z2dFS0FvSUJBUURHaVM0TUxDVkR4dEl1OEdkVjRHWFZqb0o4bkh6YTM4d1JXd0w4cjIzTAozVmJKaW1EVmpqcmhUZGk4ekdGTSs4T2ZHWDVjQm9uZURuZ0FDTVRHTE9QdDZaalRUZXI4K2VkbjBuaEdSaHNICmxEeVlBU1Q5Y1Jhb3pPdXZqNlpNU3NTNDRSQWFaYlJqb2dZdmY3Q0JzVlNLQnViY2tITlFsaFkwcWtkVGdTd3YKN0VwUHlSakdCcEtCTmNBVnFORjN3YXR3OE5JRXNEVlFwMFN2Y1ZSd3crS215am9OV0pSRnRZM1hULzhhT0llQwo2SVhwRVdncHZvWjZDMWNYZnZRY3hrVDVrN01HM2duR0dxZW4zeTBBSzZsU2FwRTdmRVZhWFhLSXZwR0hWbklNCjE4NEg3U1JoQ2V0WlorZVRNQWpFc1dVNFREK3VxZmw5ZnBpZW5TTzZjU1hGQWdNQkFBR2pnYVF3Z2FFd0N3WUQKVlIwUEJBUURBZ1F3TUJNR0ExVWRKUVFNTUFvR0NDc0dBUVVGQndNQk1GNEdBMVVkRVFSWE1GV0NEM2RsWW1odgpiMnN0YzJWeWRtbGpaWUllZDJWaWFHOXZheTF6WlhKMmFXTmxMbmRsWW1odmIyc3RjM2x6ZEdWdGdpSjNaV0pvCmIyOXJMWE5sY25acFkyVXVkMlZpYUc5dmF5MXplWE4wWlcwdWMzWmpNQjBHQTFVZERnUVdCQlNRclZCZ0VvUWQKUWRWUEhzcWpsWmdGSkdJRVJUQU5CZ2txaGtpRzl3MEJBUXNGQUFPQ0FRRUFHY0VZdEp5NHFZTzZHOXdqS3BLMQp2U3lsZG9EeDNydXh3UXN3U3RKbWZMd3lYMU1WYzZUdUZ1Q0YyRi9sdnVJOEdrZG50VUE0dWd5VksyTHU0Qm9PCmFSTWpJaFJuWkkxMWZOSXVlMDRGRXpIOWhVRDh1aVVubUlsYjJVNUhsMWRSVXZKckZsQmtURldoSGdCZll2dzkKQTU1MXBWOTliK2NES29MR0VDVXhMeE1xWHdKdktBQ3M0MnJScmZDbGZHUmF0amg2QmdHaEo4Y25hYmwzU2IrQwoxR3dodlRJOGdHUmoya29EaW9idTFEVTk3a3VxNWdBNmZ2Vk9CeitqU1BzL1d6NmVtZ3d5ekN3aDRvcUpDVkdaCnF5MkgzYnl5M2pWME9FcXhxRVpaN3FmcVRVeHJLYWVBbVFGYlZpanhZbzAwY1k2WTFaU1VQV1JKeWhVajNFczQKOXc9PQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==
  rules:
  - operations: ["CREATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
  namespaceSelector:
    matchExpressions:
    - key: ns-label-sync
      operator: In
      values: ["enabled"]

```
kubectl get mutatingwebhookconfigurations
* Step 6: Enable Webhook per Namespace
The webhook runs only if the namespace has this label:
```
ns-label-sync=enabled
```
Example: Default Namespace
```
kubectl label namespace default ns-label-sync=enabled --overwrite
kubectl label namespace default env=prod --overwrite
kubectl label namespace default team=devops --overwrite
kubectl create deployment nginx --image=nginx -n default

```
Test Pod
```
kubectl get pod -n default -l app=nginx --show-labels

```

Result:
Pod automatically inherits namespace labels.

* Test the sample deployment

Testing Team:
-------------
# 1️⃣ Create a new namespace
```
kubectl create namespace testing
```
# 2️⃣ Label the namespace so the webhook applies
```
kubectl label namespace testing ns-label-sync=enabled env=testing team=testing --overwrite
```
# 3. Show Labels on Namespace
```
kubectl get namespace testing --show-labels
```
# 3️⃣ Create a test deployment in that namespace
```
kubectl create deployment nginx --image=nginx -n testing
```
# 4️⃣ Verify pods and labels
```
kubectl get pods -n testing --show-labels
```
# 5️⃣ Describe one pod to confirm labels came from the namespace
```
kubectl get pod -n testing -o jsonpath='{.items[0].metadata.labels}'
```

* Step 7: Full Scheduling on a Node
Create Testing Namespace
```
kubectl create namespace testing
```
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
Testing Team:
-------------
# 1️⃣ Create a new namespace
kubectl create namespace testing

# 2️⃣ Label the namespace so the webhook applies
```
kubectl label namespace testing ns-label-sync=enabled env=testing team=testing --overwrite
```
* Check Namespace Labels
```
kubectl get namespace testing --show-labels
```
* Check Pod Labels
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
