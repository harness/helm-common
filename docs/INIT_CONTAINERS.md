# Init Containers

The library chart provides reusable init container templates for common initialization patterns.

---

## Wait for Directory

Creates an init container that waits for a directory to exist on the Kubernetes node before starting the main container. Useful when pods need to ensure that host-mounted directories are available before initialization.

### Template

```yaml
{{- include "harnesscommon.initContainer.waitForDirectory" (dict
  "root" .
  "directoryPath" "/var/dumps"
  "containerName" "wait-for-dumps"
  "timeout" 300
) | nindent 8 }}
```

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `root` | Object | ✅ | - | Helm context scope (usually `.`) |
| `directoryPath` | String | ✅ | - | The directory path on the node to wait for |
| `containerName` | String | ❌ | `wait-for-directory` | Name of the init container |
| `image` | Object | ❌ | `{registry: "docker.io", repository: "busybox", tag: "1.36"}` | Container image configuration |
| `timeout` | Integer | ❌ | `300` | Maximum time in seconds to wait before failing |
| `checkInterval` | Integer | ❌ | `2` | Seconds between directory existence checks |

### Image Override

The template uses the standard `common.images.image` helper, so you can override the image globally or per-template:

```yaml
# Override globally for all images
global:
  imageRegistry: my-registry.io

# Override per-template
waitForDirectory:
  image:
    registry: custom.registry.io
    repository: custom-busybox
    tag: "latest"
    pullPolicy: Always
```

### Complete Example

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  initContainers:
{{ include "harnesscommon.initContainer.waitForDirectory" (dict
  "root" .
  "directoryPath" "/var/dumps"
  "containerName" "wait-for-dumps"
  "timeout" 600
  "checkInterval" 5
) | nindent 4 }}
  containers:
    - name: main
      image: my-app:latest
      volumeMounts:
        - name: dumps-data
          mountPath: /data
  volumes:
    - name: host-directory-check
      hostPath:
        path: /var/dumps
        type: Directory
    - name: dumps-data
      hostPath:
        path: /var/dumps
        type: Directory
```

### Important Notes

1. **Volume Mount Required**: The template expects a volume named `host-directory-check` to be defined in your pod spec, mounted to the same path as `directoryPath`.

2. **Read-Only Mount**: The init container mounts the directory as read-only for safety. It only checks for existence, not write access.

3. **Timeout Behavior**: If the directory doesn't exist within the timeout period, the init container will fail with exit code 1, preventing the main container from starting.

4. **Progress Logging**: The init container logs its progress every `checkInterval` seconds, showing elapsed time and timeout remaining.

### Use Cases

- Waiting for CSI drivers to mount volumes
- Ensuring NFS mounts are ready
- Waiting for local storage provisioners
- Coordinating with DaemonSets that prepare host directories
