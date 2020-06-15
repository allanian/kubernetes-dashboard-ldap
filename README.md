![logo.png](https://raw.githubusercontent.com/icyxp/kubernetes-dashboard-ldap/master/assets/images/logo.png)

# Origin
Why write such a tool? This is because we have more than one ` kubernetes ` cluster (8+), The apiserver configuration cannot be modified because it is hosted in the cloud
, it will bring us a pain points, **development, sre need to login to k8s dashbaord and requires a different between different departments and role authorization**, the original is through ` sa token ` log in dashboard, but as the growth of the k8s cluster, each adding a cluster, you need to inform use corresponding dashboard access addresses and corresponding token, This is painful for both the provider and the user. Is there a tool that **provides a unified address and access to multiple cluster Dashboards**? After some searching, it is found that there is no. Most of the solutions in the market are single cluster integration `LDAP` solutions, mainly `DEX` solutions, but the unified login authorization scheme of single cluster alone makes people feel very difficult. Aren't there simple and convenient tools for us to use? Well, I'm going to build a tool like this.

Dashboard LDAP integration solutions：
- [https://k2r2bai.com/2019/09/29/ironman2020/day14/](https://k2r2bai.com/2019/09/29/ironman2020/day14/)
- [https://blog.inkubate.io/access-your-kubernetes-cluster-with-your-active-directory-credentials](https://blog.inkubate.io/access-your-kubernetes-cluster-with-your-active-directory-credentials)

The above two documents are LDAP scheme, I feel good, for the need of people reference!

# How to design
> Objective: ** Simple use **!! By accessing the same address, the dashboard of different clusters can be switched using LDAP login and different cluster permissions can be configured separately!

With the above goals, how to achieve them?

The implementation method is actually very simple. First write a login interface to communicate with the company's AD to obtain users and groups, and then associate the users or groups with the `service account` in the k8s cluster to realize the corresponding rbac and login token. 
After logging in, you can complete a reverse proxy service.

Is it very simple! ! !

Implementation Technology Stack：golang(gin、client-go、viper、ldap) + [Kubernetes Dashboard](https://github.com/kubernetes/dashboard) / [Kubaord](https://kuboard.cn/install/install-dashboard.html)

# How to deploy
## Prerequisites
Before using this tool, you need to have the following conditions:
1. Dashboard has been deployed in each k8s cluster and can be accessed by this tool
2. Already have `ldap` and have administrative rights to access operations
3. Corresponding `service accounts` can be mapped in each cluster. If you need to have different operation permissions for different users and groups, you can authorize sa for rbac, which will be explained in detail below.
4. This tool needs to operate the APIs of each cluster, so you need to obtain the `apiserver address`, `ca.crt` and `token` of each cluster for configuration. As for the `ca.crt` and `token` of each cluster, if you get it, Will be explained later

## How to get ca.crt and token
This tool needs to operate the API of each cluster to obtain the corresponding sa and token, so it needs to have permission to operate each cluster. How to generate corresponding CA certificates and tokens in each cluster? The answer is to create an sa and give certain permissions.

Execute the following yaml file in each k8s cluster:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: mutiboard-ldap
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: mutiboard-ldap-crb
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: mutiboard-ldap-view
subjects:
- kind: ServiceAccount
  name: mutiboard-ldap
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: mutiboard-ldap-view
rules:
- apiGroups:
  - ""
  resources:
  - serviceaccounts
  - secrets
  verbs:
  - get
  - list
- apiGroups:
  - ""
  resources:
  - namespaces
  verbs:
  - get
  - list
  - watch
```
The meaning of this yaml file: create an sa named `mutiboard-ldap`, and give get and list permissions to `serviceaccounts` and `secrets`.

Get the ca.crt of `mutiboard-ldap`:
```bash
(⎈|aws-local:default)❯ echo $(kubectl get secret $(kubectl get secret | grep mutiboard-ldap | awk '{print $1}') -o go-template='{{index .data "ca.crt"}}') | base64 -d

-----BEGIN CERTIFICATE-----
MIICyDCCAbCgAwIBAgIBADANBgkqhkiG9w0BAQsFADAVMRMwEQYDVQQDEwprdWJl
cm5ldGVzMB4XDTE5MDEyNTEwMTgzNFoXDTI5MDEyMjEwMTgzNFowFTETMBEGA1UE
AxMKa3ViZXJuZXRlczCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMmc
TW0stLLP+M6Pc9wpRgZufg6eQ7puBfbYgik20QlO4LFtocgNUDa0y+aSXjxheA2C
A+o9wW0IC3GHQHKgeFY8KXIJu6wM0TO+JNQy5XZAWfbsLeXU/sLhKuWET/KJzVWT
0uBE+GCADAAQIec1oQXMbQ551hU5gBFcr67NXHpa2qwEGA1mGtZ7ztmW4+IFUD74
G166z4AOgmR4YWxBs/+8NhfWudFD32xevBfSKuHRxRGG5dtffY8QnRbnrmy70HE5
yzLtBvAGfCwtHLTP2ngCAnn2Fb6IeMdIYGpI1544ZjRbzT1YIWsG1v3dlu6tvK1q
X5Pj+UTDmJuf2SW52A0CAwEAAaMjMCEwDgYDVR0PAQH/BAQDAgKkMA8GA1UdEwEB
/wQFMAMBAf8wDQYJKoZIhvcNAQELBQADggEBAKE2hV0DIG8fSf4/eOi5R2sPRfBW
qTwgZDDT9dxZNhbxEInALdruwRUbKRpwaUBOGVpIlaK3/rZkAfjUwoDJ+J4fmmCX
w3ySrYFjx6tqVFqCPjDkBHh4xpMwUlvsvryRuCEQUQgjqBvj6sWm9GERF2n3VYBF
S8bjsQQAZJoE4W+OKchlEoSFlKhxAoeZx9CD3Rxnhj2og6doVoGCUqAMh4WZWX+w
pENnui6M96SysH3SkrA02RXWTGeKzK4E6Av3IG+2a2hauHorbqVfaM6HeL3hkU/B
JCWpOgN3T4Fw7E359CBQxnSHPasmZ5VBoyIk/HUU6ZlMK6Xo6JlbS7ZvVl4=
-----END CERTIFICATE-----
```

Get the token of `mutiboard-ldap`:
```bash
(⎈|aws-local:default)❯ echo $(kubectl get secret $(kubectl get secret | grep mutiboard-ldap | awk '{print $1}') -o go-template='{{.data.token}}') | base64 -d

eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJkZWZhdWx0Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6Im11dGlib2FyZC1sZGFwLXRva2VuLWJ3NWdmIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6Im11dGlib2FyZC1sZGFwIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiMjVmZjI4MGQtYWJhMi0xMWVhLWFlOGEtMDIzOTBjMzcyNzhlIiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50OmRlZmF1bHQ6bXV0aWJvYXJkLWxkYXAifQ.q14hqEu2p70_YczDviR6c8McDM5vfnKPzjO9usCsC-uQUxciBbuJU_PK9j3uawppUNlrs3rAPrZIGUS7Jv14rifEXpGxIIfGR6n8-le0b-9YvMZCgs9-jhf-1r01EAnZFh6gcXfxESFguFQI0vYOsX4P2LQvZ9XTMzsqXbW3KGYao5elAjCE4e8Rg4--9e_zU8NGTEycsvUMxP-9p0SaAzn9Iak3saZtAnzJq5hkSf1t7l2_CgEsYN-3b7uGpHupK_zdgAeOflj9ze4Cz2YScv5eixwVXJ-RcI4lgSFCgt5yzSbnIuHgxRZyN3NcYLrSBYKftezZysWm3jELgLPogQ
```

At this point, the `ca.crt` and `token` of each cluster have been obtained. The following will tell how to configure and use these `ca.crt` and `token`

## SA RBAC example
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ops-admin
  namespace: default
  labels:
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: ops-role
rules:
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list", "watch"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: ops-listnamespace
roleRef: #Referenced role
  kind: ClusterRole
  name: ops-role
  apiGroup: rbac.authorization.k8s.io
subjects: #principal part
- kind: ServiceAccount
  name: ops-admin
  namespace: default
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: ops-ci-admin
  namespace: ops-ci
roleRef: #Referenced role
  kind: ClusterRole
  name: admin
  apiGroup: rbac.authorization.k8s.io
subjects: #principal part
- kind: ServiceAccount
  name: ops-admin
  namespace: default
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: ops-qa-admin
  namespace: ops-qa
roleRef: #Referenced role
  kind: ClusterRole
  name: admin
  apiGroup: rbac.authorization.k8s.io
subjects: #principal part
- kind: ServiceAccount
  name: ops-admin
  namespace: default
```
The meaning of this YAML is: create an ops-admin sa, and give this sa two namespace (ops-ci, ops-qa) admin permissions.

For more information about rbac, please refer to：[https://www.cnblogs.com/wlbl/p/10694364.html](https://www.cnblogs.com/wlbl/p/10694364.html)

## LDAP description
Our `ldap` directory rules are as follows:
```
|--domain
|----|---company
|----|----|----subsidiary
|----|----|-----|----department
|----|----|-----|-----|-----user
```

The corresponding `Distinguished Name` is shown below：
```
CN=Peng Xu,OU=department,OU=subsidiary,OU=company,DC=corp,DC=xxx,DC=com
```
Here I will get the first `OU` as a `group`, if your needs are different from mine, you can give me an issue to adapt

For details, please refer to：[https://blog.poychang.net/ldap-introduction](https://blog.poychang.net/ldap-introduction)

## Configmap.yaml configuration instructions
```yaml
ldap:
  addr: ldap://192.168.3.81:389
  adminUser: xxxxx
  adminPwd: xxxxxx
  baseDN: dc=corp,dc=patsnap,dc=com
  filter: (&(objectClass=person)(sAMAccountName=%s))
  attributes: user_dn
  orgUnitName: OU=
#mapping of global users/user groups to SA
rbac:
  DevOps team:
    sa: ops-admin
    ns: kube-system
  xupeng:
    sa: inno-admin
    ns: default
clusters:
  #Cluster alias, the key displayed in the login drop-down box, this alias needs to correspond to the key names of ca.crt and token in secret.sh
  local:
    #apiserver address, can be accessed by the current tool
    apiServer: apiserver-dev.jiunile.com
    port: 6443
    #kubernetes dashboard address, can be accessed by the current tool
    dashboard: dashboard-dev.jiunile.com
    #Cluster description, the name displayed in the login drop-down box
    desc: Dev Cluster
    #Segmentation for individual clusters
    #rbac:
    #  DevOps team:
    #    sa: admin
    #    ns: kube-system
    #  xupeng:
    #    sa: ops-admin
    #    ns: default
  cnrelease:
    apiServer: apiserver-cn-release.jiunile.com
    port: 443
    dashboard: https://dashboard-cn-release.jiunile.com
    desc: CN Release Cluster
  usrelease:
    apiServer: apiserver-us-release.jiunile.com
    port: 443
    dashboard: https://dashboard-us-release.jiunile.com
    desc: US Release Cluster
  euprod:
    apiServer: apiserver-eu-prod.jiunile.com
    port: 443
    dashboard: https://dashboard-eu-prod.jiunile.com
    desc: EU Prod Cluster
  dataprod:
    apiServer: apiserver-data-prod.jiunile.com
    port: 443
    dashboard: http://kuboard-data-prod.jiunile.com
    desc: DATA Prod Cluster
    type: kuboard
``` 
## Deploy
1. Modify and deploy `deploy/configmap.yaml`
2. Write the `ca.crt` and `token` obtained by each cluster to the corresponding deploy/token
3. Execute the secret.sh script under deploy `sh deploy/secret.sh`
    > Note: The `xx` in `xx_token/xxx_ca.crt` in secret.sh corresponds to the **cluster alias in `configmap.yaml`, which must correspond one-to-one**
    
1. deploy `deploy/deployment.yaml`

## Visit
http://{nodeip}:31000

[![mutiboard-ldap](http://img.youtube.com/vi/ILiviSLbSq8/0.jpg)](http://www.youtube.com/watch?v=ILiviSLbSq8 "kubernetes muti dashboard ldap login")

Video download address: [https://github.com/icyxp/kubernetes-dashboard-ldap/raw/master/assets/video/intro.webm](https://github.com/icyxp/kubernetes-dashboard-ldap/raw/master/assets/video/intro.webm)

# Donation
if you are willing to.

|Alipay|Wxpay|Wechat group|
|:-----:|:-----:|:-----:|
|![alipay](https://raw.githubusercontent.com/icyxp/kubernetes-dashboard-ldap/master/assets/donate/alipay.png)|![weixin](https://raw.githubusercontent.com/icyxp/kubernetes-dashboard-ldap/master/assets/donate/wxpay.png)|![weixin group](https://raw.githubusercontent.com/icyxp/kubernetes-dashboard-ldap/master/assets/donate/weixin.jpeg)|


