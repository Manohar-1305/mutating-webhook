openssl req -newkey rsa:4096 -nodes -keyout tls.key -x509 -days 365 -out tls.crt -subj "/CN=webhook.default.svc"
openssl req -x509 -newkey rsa:4096 -keyout tls.key -out tls.crt -days 365 -nodes   -subj "/CN=webhook-service.default.svc"   -addext "subjectAltName = DNS:webhook-service.default.svc"

kubectl create secret tls webhook-tls --cert=tls.crt --key=tls.key -n default
docker build -t manoharshetty507/webhook:v1 .
docker push manoharshetty507/webhook:v1
kubectl apply -f webhook-deployment.yaml
kubectl apply -f webhook-configuration.yaml
kubectl get mutatingwebhookconfiguration

kubectl get secret webhook-tls -n default -o jsonpath='{.data.tls\.crt}'

kubectl label namespace default team=dev env=staging
kubectl get pod test-pod -o jsonpath='{.metadata.labels}'

openssl req -x509 -newkey rsa:4096 -keyout webhook.key -out webhook.crt -days 365 -nodes -subj "/CN=webhook-service"
openssl req -newkey rsa:4096 -nodes -keyout tls.key -x509 -days 365 -out tls.crt -subj "/CN=webhook-service.default.svc"

kubectl create secret tls webhook-tls --cert=webhook.crt --key=webhook.key -n default

