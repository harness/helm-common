# Fix JFR "POD_NAME isn't writable" Error

## Problem
Pods crash with:
```
Could not use /opt/harness/POD_NAME as repository. 
JFR repository directory (/opt/harness/POD_NAME) exists, but isn't writable
```

## Fix (3 steps)

### 1. Update harness-common to 1.5.2+

Edit `Chart.yaml`:
```yaml
dependencies:
  - name: harness-common
    version: 1.5.2  # Change this
```

### 2. Update dependencies

```bash
helm dependency update
```

### 3. Deploy

```bash
helm upgrade --install my-release . --values values.yaml
```

## Verify

Check pods start:
```bash
kubectl get pods
```

Check init container logs:
```bash
kubectl logs <pod-name> -c init-jfr-c03846b08a9d4837
```

Should see: `✓ Symlink verified`

---

## Why this works

Version 1.5.2+ includes an init container that creates the `/opt/harness/POD_NAME` symlink **before** the JVM starts, fixing the race condition.

For full JFR documentation, see [JFR.md](./JFR.md).
