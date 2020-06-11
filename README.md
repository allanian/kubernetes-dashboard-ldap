<p align="center">
    <a href="javascript:;" target="_blank"><img src="http://www.jiunile.com/tmp/mutiboard.png"></a>
</p>

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
## SA RBAC讲解
## 配置说明

# 捐助
如果你愿意.

|支付宝|微信|群二维码|
|:-----:|:-----:|:-----:|
|![alipay](https://raw.githubusercontent.com/icyxp/kubernetes-dashboard-ldap/master/assets/donate/alipay.png)|![weixin](https://raw.githubusercontent.com/icyxp/kubernetes-dashboard-ldap/master/assets/donate/wxpay.png)|![weixin 群](https://raw.githubusercontent.com/icyxp/kubernetes-dashboard-ldap/master/assets/donate/weixin.jpeg)|

