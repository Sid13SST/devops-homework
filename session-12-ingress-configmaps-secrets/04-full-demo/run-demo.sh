#!/usr/bin/env bash
# Session 12 - end-to-end automated deployment
set -e
D="$(dirname "$0")"
echo "==> Applying ConfigMap"; kubectl apply -f "$D/configmap.yaml"
echo "==> Applying Secret";    kubectl apply -f "$D/secret.yaml"
echo "==> Applying Backend (Deployment + Service)";  kubectl apply -f "$D/backend.yaml"
echo "==> Applying Frontend (Deployment + Service)"; kubectl apply -f "$D/frontend.yaml"
echo "==> Applying Ingress";   kubectl apply -f "$D/ingress.yaml"
echo "==> Waiting for rollouts"
kubectl rollout status deployment/yatri-backend  --timeout=120s
kubectl rollout status deployment/yatri-frontend --timeout=120s
echo "==> Stack ready"
kubectl get configmap,secret,ingress,deploy,svc,pods -l app=yatri-app
