## 2.1.0
增加审计日志

---

Add Audit Log

---
Audit Log example:
```
INFO[0039] 127.0.0.1 - imroc.local [16/Dec/2020:13:55:24 +0800] "GET /api/v1/pod/default" 200 1030 "http://127.0.0.1:8000/" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.198 Safari/537.36" "" (1ms)  clientIP=127.0.0.1 dataLength=1030 hostname=imroc.local latency=1 method=GET path=/api/v1/pod/default referer="http://127.0.0.1:8000/" statusCode=200 traceID= user=admin userAgent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.198 Safari/537.36"
```

## 2.0.0
1. 支持 LDAP 和 token 登录
2. 根据不同的集群登录显示不同的 Logo（左上角）
3. 配置中增加默认选中集群功能
4. 优化代码，增加 pprof & statsviz(:8888)
---
1. Support LDAP and token login
2. Display different logo according to the selection of the cluster
3. `configmap.yaml` add `default:true`
4. Optimized code and fix some bug, add pprof & statsviz(:8888)