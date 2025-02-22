openssl req -newkey rsa:4096 -nodes -keyout tls.key -x509 -days 365 -out tls.crt -subj "/CN=webhook.default.svc"
kubectl create secret tls webhook-tls --cert=tls.crt --key=tls.key -n default
docker build -t manoharshetty507/webhook:v1 .
docker push myregistry/webhook:v1
kubectl apply -f webhook-deployment.yaml
kubectl apply -f webhook-configuration.yaml

kubectl label namespace default team=dev env=staging
kubectl get pod test-pod -o jsonpath='{.metadata.labels}'
