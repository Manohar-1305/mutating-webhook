openssl req -newkey rsa:4096 -nodes -keyout tls.key -x509 -days 365 -out tls.crt -subj "/CN=webhook.default.svc"
openssl req -x509 -newkey rsa:4096 -keyout tls.key -out tls.crt -days 365 -nodes   -subj "/CN=webhook-service.default.svc"   -addext "subjectAltName = DNS:webhook-service.default.svc"

kubectl create secret tls webhook-tls --cert=tls.crt --key=tls.key -n default
docker build -t manoharshetty507/webhook:v1 .
 docker tag manoharshetty507/webhook:v2 manoharshetty507/webhook:v2

docker push manoharshetty507/webhook:v1
kubectl apply -f webhook-deployment.yaml
kubectl apply -f webhook-configuration.yaml
kubectl get mutatingwebhookconfiguration
docker rmi -f $(docker images -q)

kubectl get secret webhook-tls -n default -o jsonpath='{.data.tls\.crt}'

kubectl label namespace default team=dev env=staging
kubectl get pod test-pod -o jsonpath='{.metadata.labels}'

openssl req -x509 -newkey rsa:4096 -keyout webhook.key -out webhook.crt -days 365 -nodes -subj "/CN=webhook-service"
openssl req -newkey rsa:4096 -nodes -keyout tls.key -x509 -days 365 -out tls.crt -subj "/CN=webhook-service.default.svc"

kubectl create secret tls webhook-tls --cert=webhook.crt --key=webhook.key -n default

cat webhook.crt | base64 | tr -d '\n'

-------------------------------------------
openssl genrsa -out ca.key 2048
openssl req -new -x509 -days 365 -key ca.key -subj "/C=CN/ST=GD/L=SZ/O=Acme, Inc./CN=Acme Root CA" -out ca.crt

export SERVICE=webhook-service
openssl req -newkey rsa:2048 -nodes -keyout tls.key -subj "/C=CN/ST=GD/L=SZ/O=Acme, Inc./CN=$SERVICE.default.svc.cluster.local" -out tls.csr
openssl x509 -req -extfile <(printf "subjectAltName=DNS:$SERVICE.default.svc.cluster.local,DNS:$SERVICE.default.svc.cluster,DNS:$SERVICE.default.svc,DNS:$SERVICE.default.svc,DNS:$SERVICE.default,DNS:$SERVICE") -days 365 -in tls.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out tls.crt

kubectl create secret tls tls --cert=tls.crt --key=tls.key

CA_CERT=$(cat tls.crt | base64)
sed -e 's@CA-CERT@'"$CA_CERT"'@g' <"manifests/webhook-template.yaml" > manifests/webhook.yaml
kubectl apply -f manifests/webhook.yaml

-------------------------------------------
openssl req -new -newkey rsa:2048 -nodes -keyout tls.key -out tls.csr -subj "/CN=webhook-service.default.svc"
openssl x509 -req -in tls.csr -signkey tls.key -out tls.crt -days 365
ls -l
CA_CERT=$(cat tls.crt | base64 | tr -d '\n')
echo $CA_CERT
sed -i "s|\${CA_BUNDLE}|${CA_CERT}|g" webhook-configuration.yaml
grep caBundle webhook-configuration.yaml

kubectl create secret tls webhook-tls --cert=tls.crt --key=tls.key -n default


kubectl apply -f webhook-configuration.yaml
kubectl apply -f webhook-deployment.yaml

kubectl get mutatingwebhookconfigurations
=========================
working
=========================
Add mutaring webhook
vi /etc/kubernetes/manifests/kube-apiserver.yaml

change it to: --enable-admission-plugins=NodeRestriction,MutatingAdmissionWebhook,ValidatingAdmissionWebhook
===============
Generate a san
===============
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
===========================================
# Create a certificate
openssl genrsa -out tls.key 2048

openssl req -new -key tls.key -out tls.csr -config san.cnf

openssl x509 -req -in tls.csr -signkey tls.key \
  -out tls.crt -days 365 \
  -extensions v3_req -extfile san.cnf

 ===========
kubectl delete secret webhook-tls -n webhook-system --ignore-not-found
# Create a secret
kubectl create secret tls webhook-tls \
  --cert=tls.crt \
  --key=tls.key \
  -n webhook-system
==============
# Build the image
docker build -t manoharshetty507/webhook:v2 .
ctr -n k8s.io images import <(docker save manoharshetty507/webhook:v3)
===========================================
kubectl rollout restart deployment webhook -n webhook-system
kubectl delete deployment nginx -n test --ignore-not-found
kubectl create deployment nginx --image=nginx -n test
kubectl get pods -n test --show-labels
===========================================================
kubectl rollout restart deployment webhook -n webhook-system
kubectl delete deployment nginx -n test --ignore-not-found
kubectl create deployment nginx --image=nginx -n test
kubectl get pods -n test --show-labels


===========================================================
encode
base64 -w0 tls.crt
==========================================================
kubectl delete deployment nginx -n test --ignore-not-found
kubectl create deployment nginx --image=nginx -n test
kubectl get pods -n test --show-labels

Enable ns 
kubectl label namespace test ns-label-sync=enabled


test the sample yaml
kubectl label namespace default ns-label-sync=enabled --overwrite
kubectl label namespace default env=from-ns --overwrite
kubectl label namespace default team=devops --overwrite
kubectl apply -f testing-pod.yaml
kubectl get pod test-pod -n default --show-labels

------------------------------
# 1️⃣ Create a new namespace
kubectl create namespace prod

# 2️⃣ Label the namespace so the webhook applies
kubectl label namespace prod ns-label-sync=enabled env=prod team=development --overwrite

kubectl get namespace prod --show-labels


# 3️⃣ Create a test deployment in that namespace
kubectl create deployment nginx --image=nginx -n prod

# 4️⃣ Verify pods and labels
kubectl get pods -n prod --show-labels

# 5️⃣ Describe one pod to confirm labels came from the namespace
kubectl get pod -n prod -o jsonpath='{.items[0].metadata.labels}'

Testing Team:
-------------
# 1️⃣ Create a new namespace
kubectl create namespace testing

# 2️⃣ Label the namespace so the webhook applies
kubectl label namespace testing ns-label-sync=enabled env=testing team=testing --overwrite

kubectl get namespace testing --show-labels


# 3️⃣ Create a test deployment in that namespace
kubectl create deployment nginx --image=nginx -n testing

# 4️⃣ Verify pods and labels
kubectl get pods -n testing --show-labels

# 5️⃣ Describe one pod to confirm labels came from the namespace
kubectl get pod -n testing -o jsonpath='{.items[0].metadata.labels}'
------------------------------------
docker build -t manoharshetty507/webhook:v2 .
ctr -n k8s.io images import <(docker save manoharshetty507/webhook:v3)

docker images
docker tag manoharshetty507/webhook:v2 manoharshetty507/webhook:v2
docker push manoharshetty507/webhook:v2

- Label Node
kubectl label node master01 team=testing

- Remove Label on Node
kubectl label node master01 team-

kubectl label namespace prod ns-label-sync=enabled env=testing team=testing --overwrite

kubectl get pod -n prod -o yaml | grep -A5 nodeSelector

