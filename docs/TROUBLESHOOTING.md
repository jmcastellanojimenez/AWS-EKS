# 🔧 Troubleshooting Guide

Quick fixes for common EKS and ingress issues.

## 🚨 Common Quick Fixes

### Issue: "EntityAlreadyExists: Role already exists"
**Fix:** Run cleanup workflow first → Pattern=`alb`, Confirmation=`CONFIRM-CLEANUP`

### Issue: Multiple Route53 Zones  
**Fix:** Delete extra zones in AWS Console, keep only 1

### Issue: ALB Not Created
**Fix:** Deploy with `Deploy Apps: true`, check controller: `kubectl get pods -n kube-system | grep aws-load-balancer`

### Issue: SSL Certificate Not Ready
**Fix:** Use `letsencrypt-staging` issuer first, check DNS propagation

---

## 🛠️ Quick Diagnostics

```bash
# Health check
kubectl cluster-info
kubectl get pods --all-namespaces | grep -v Running

# Ingress status
kubectl get ingress --all-namespaces
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=20

# DNS & SSL
nslookup demo-alb.k8s-demo.local
kubectl get certificate --all-namespaces
```

---

## 🚨 Emergency Recovery

**Complete Reset:**
1. 🧹 Cleanup: Pattern=`all`, Cleanup Shared=`true`
2. 🚀 EKS Infrastructure: Action=`destroy`
3. Redeploy from scratch

---

## 📞 Getting Help

1. Check workflow logs in GitHub Actions
2. Use diagnostic commands above  
3. Review [WORKFLOWS.md](./WORKFLOWS.md)
4. Create GitHub issue with logs and steps to reproduce