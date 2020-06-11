cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: k8s-mutiboard-ldap-cert
  namespace: kube-system
  labels:
    app: k8s-mutiboard-ldap
type: Opaque
data:
  local_token: $(cat ./token/cluster1/token | base64)
  local_ca.crt: $(cat ./token/cluster1/ca.crt | base64)
  cnrelease_token: $(cat ./token/cluster2/token | base64)
  cnrelease_ca.crt: $(cat ./token/cluster2/ca.crt | base64) 
  usrelease_token: $(cat ./token/cluster3/token | base64)
  usrelease_ca.crt: $(cat ./token/cluster3/ca.crt | base64)  
  euprod_token: $(cat ./token/cluster4/token | base64)
  euprod_ca.crt: $(cat ./token/cluster4/ca.crt | base64)     
EOF