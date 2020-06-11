![logo.png](https://raw.githubusercontent.com/icyxp/kubernetes-dashboard-ldap/master/assets/images/logo.png)

# 工具由来
为什么要写这样的一个工具呢？这是因为我司有多个 `kubernetes` 集群(8+)，且都是云托管服务无法接触到Apiserver配置，这就给我们带来一个痛点，**开发、sre需要登录k8s dashbaord且不同部门和角色间需要不同的授权**，原先都是通过 `sa token` 进行登录dashboard，但随着k8s集群的增长，每增加一个集群，就需要告知使用方对应dashboard访问地址以及对应的token，这不管是提供方还是使用方都让人感觉非常的痛苦。那是否有一款工具能**提供统一地址统一登录多集群dashboard的方案**呢？经过一番搜索后，发现并没有，市面上大多数是单集群集成 `LDAP` 的方案，主要是以 `DEX` 为主，但光单集群的统一登录授权方案就让人感觉非常的困难。难道就没有简单方便的工具供我们使用吗？好吧，那我就来打造这样一款工具吧。

Dashboard LDAP集成方案：
- [https://k2r2bai.com/2019/09/29/ironman2020/day14/](https://k2r2bai.com/2019/09/29/ironman2020/day14/)
- [https://blog.inkubate.io/access-your-kubernetes-cluster-with-your-active-directory-credentials](https://blog.inkubate.io/access-your-kubernetes-cluster-with-your-active-directory-credentials)

以上两篇文档是成LDAP的方案，个人感觉还不错，供有需要的人参考！

# 如何打造
好吧既然没有，那就自动动手打造一个！
> 目标： **简单使用**！！！通过访问同一地址，使用LDAP登录且可切换不同集群的dashboard，同时对应不同的集群权限可单独配置！

有了上面的目标，那如何来实现呢？

实现方式其实很简单，首先写一个登录界面与公司的AD进行打通获取用户与组，然后将用户或者组与k8s集群中的 `service account` 进行关联就实现了对应的rbac与登录token，最后在登录后实现一个反向代理服务即可完成。

是不是非常的简单！！！

实现技术栈：golang(gin、client-go、viper、ldap) + Kubernetes Dashboard
# 如何部署
## 前提条件
在使用此工具前，需要有以下一些条件约束：
1. 已在各k8s集群部署 `dashboard` 且能被此工具访问到
2. 已有 `ldap` 且有管理权限能进行访问操作
3. 各集群中有对应的 `service account` 可进行映射，如需对不同用户和组需要有不同的操作权限，则对sa进行rbac授权即可，下面会详细说明。
4. 此工具需要操作各集群的api，故需要获取每个集群的 `apiserver地址`、`ca.crt` 以及 `token` 进行配置，至于每个集群的 `ca.crt` 和 `token` 如果获取，后面会进行说明

## 如何获取 ca.crt 及 token
此工具需要操作每个集群的api来获取对应的 sa 以及 token，故需要有对各集群操作的权限。那如何在各集群生成对应的 ca证书 及 token 呢？答案就是创建一个 sa 并给予一定的权限。

在每个k8s集群中执行如下yaml文件:
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
此yaml文件的含义：创建一个名为`mutiboard-ldap`的 sa，并且给予`serviceaccounts`和`secrets`的get和list的权限。

获取 `mutiboard-ldap` 的 ca.crt：
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

获取 `mutiboard-ldap` 的 token：
```bash
(⎈|aws-local:default)❯ echo $(kubectl get secret $(kubectl get secret | grep mutiboard-ldap | awk '{print $1}') -o go-template='{{.data.token}}') | base64 -d

eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJkZWZhdWx0Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6Im11dGlib2FyZC1sZGFwLXRva2VuLWJ3NWdmIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6Im11dGlib2FyZC1sZGFwIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiMjVmZjI4MGQtYWJhMi0xMWVhLWFlOGEtMDIzOTBjMzcyNzhlIiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50OmRlZmF1bHQ6bXV0aWJvYXJkLWxkYXAifQ.q14hqEu2p70_YczDviR6c8McDM5vfnKPzjO9usCsC-uQUxciBbuJU_PK9j3uawppUNlrs3rAPrZIGUS7Jv14rifEXpGxIIfGR6n8-le0b-9YvMZCgs9-jhf-1r01EAnZFh6gcXfxESFguFQI0vYOsX4P2LQvZ9XTMzsqXbW3KGYao5elAjCE4e8Rg4--9e_zU8NGTEycsvUMxP-9p0SaAzn9Iak3saZtAnzJq5hkSf1t7l2_CgEsYN-3b7uGpHupK_zdgAeOflj9ze4Cz2YScv5eixwVXJ-RcI4lgSFCgt5yzSbnIuHgxRZyN3NcYLrSBYKftezZysWm3jELgLPogQ
```
至此，各集群的 `ca.crt` 和 `token` 都已获取，下面会告知如何进行配置使用这些 `ca.crt` 和 `token`

## SA RBAC列子
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
roleRef: #引用的角色
  kind: ClusterRole
  name: ops-role
  apiGroup: rbac.authorization.k8s.io
subjects: #主体
- kind: ServiceAccount
  name: ops-admin
  namespace: default
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: ops-ci-admin
  namespace: ops-ci
roleRef: #引用的角色
  kind: ClusterRole
  name: admin
  apiGroup: rbac.authorization.k8s.io
subjects: #主体
- kind: ServiceAccount
  name: ops-admin
  namespace: default
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: ops-qa-admin
  namespace: ops-qa
roleRef: #引用的角色
  kind: ClusterRole
  name: admin
  apiGroup: rbac.authorization.k8s.io
subjects: #主体
- kind: ServiceAccount
  name: ops-admin
  namespace: default
```
这段YAML的意思为：创建了一个ops-admin的sa，并为这个sa赋予了两个命名空间(ops-ci、ops-qa) admin 的权限。

具体想了解更多rbac相关的说明，可参考：[https://www.cnblogs.com/wlbl/p/10694364.html](https://www.cnblogs.com/wlbl/p/10694364.html)

## ldap说明
我司`ldap`目录规则如下：
```
|--域
|--|---公司
|--|----|----分公司
|--|----|-----|----部门
|--|----|-----|-----|-----用户
```

对应的`Distinguished Name`显示如下：
```
CN=Peng Xu,OU=部门,OU=分公司,OU=公司,DC=corp,DC=xxx,DC=com
```
这里我会获取第一个`OU`作为`group`，如果你的需求和我不一样，可以给我提 issue 进行适配

ldap 详细说明请参考：[https://blog.poychang.net/ldap-introduction](https://blog.poychang.net/ldap-introduction)

## configmap.yaml 配置说明
```yaml
ldap:
  addr: ldap://192.168.3.81:389
  adminUser: xxxxx
  adminPwd: xxxxxx
  baseDN: dc=corp,dc=patsnap,dc=com
  filter: (&(objectClass=person)(sAMAccountName=%s))
  attributes: user_dn
  orgUnitName: OU=
#全局用户/用户组与SA的映射
rbac:
  DevOps team:
    sa: ops-admin
    ns: kube-system
  xupeng:
    sa: inno-admin
    ns: default
clusters:
  #集群别名，在登录下拉框中显示的key，这个别名需要和secret.sh中的ca.crt和token的键名一一对应
  local:
    #apiserver地址，能够被当前工具访问到
    apiServer: apiserver-dev.jiunile.com
    port: 6443
    #kubernetes dashboard地址，能够被当前工具访问到
    dashboard: dashboard-dev.jiunile.com
    #集群说明，在登录下拉框中显示的名称
    desc: Dev Cluster
    #针对单独集群细分
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
    dashboard: dashboard-cn-release.jiunile.com
    desc: CN Release Cluster
  usrelease:
    apiServer: apiserver-us-release.jiunile.com
    port: 443
    dashboard: dashboard-us-release.jiunile.com
    desc: US Release Cluster
  euprod:
    apiServer: apiserver-eu-prod.jiunile.com
    port: 443
    dashboard: dashboard-eu-prod.jiunile.com
    desc: EU Prod Cluster
``` 
## 部署
1. 修改并部署`deploy/configmap.yaml`
2. 将各集群获取的 `ca.crt` 和 `token` 写入到对应的deploy/token下
3. 执行 deploy 下的 secret.sh 脚本 `sh deploy/secret.sh`
    > 注意: secret.sh 中的`xx_token/xxx_ca.crt`中的 `xx` 对应于`configmap.yaml` 中的**集群别名，必须要一一对应**
    
4. 部署`deploy/deployment.yaml`

## 访问
http://{nodeip}:31000

视频：
[![mutiboard-ldap](http://img.youtube.com/vi/ILiviSLbSq8/0.jpg)](http://www.youtube.com/watch?v=ILiviSLbSq8 "kubernetes muti dashboard ldap login")

视频地址: [https://github.com/icyxp/kubernetes-dashboard-ldap/raw/master/assets/video/intro.webm](https://github.com/icyxp/kubernetes-dashboard-ldap/raw/master/assets/video/intro.webm)

# 捐助
如果你愿意.

|支付宝|微信|群二维码|
|:-----:|:-----:|:-----:|
|![alipay](https://raw.githubusercontent.com/icyxp/kubernetes-dashboard-ldap/master/assets/donate/alipay.png)|![weixin](https://raw.githubusercontent.com/icyxp/kubernetes-dashboard-ldap/master/assets/donate/wxpay.png)|![weixin 群](https://raw.githubusercontent.com/icyxp/kubernetes-dashboard-ldap/master/assets/donate/weixin.jpeg)|

