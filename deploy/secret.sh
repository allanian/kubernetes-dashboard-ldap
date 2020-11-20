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
  local_token: $(openssl base64 -in ./token/cluster1/token -A)  
  local_ca.crt: $(openssl base64 -in ./token/cluster1/ca.crt -A)
  cnrelease_token: $(openssl base64 -in ./token/cluster2/token -A)  
  cnrelease_ca.crt: $(openssl base64 -in ./token/cluster2/ca.crt -A)
  usrelease_token: $(openssl base64 -in ./token/cluster3/token -A) 
  usrelease_ca.crt: $(openssl base64 -in ./token/cluster3/ca.crt -A)
  euprod_token: $(openssl base64 -in ./token/cluster4/token -A) 
  euprod_ca.crt: $(openssl base64 -in ./token/cluster4/ca.crt -A)    
EOF