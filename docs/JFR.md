# Using JFR with harness-common

The library chart provides templates for [Java Flight Recorder (JFR)](https://docs.oracle.com/javacomponents/jmc-5-4/jfr-runtime-guide/about.htm) to enable continuous profiling, diagnostics, and dump collection for Java applications. When enabled, JFR automatically captures performance data and collects thread dumps, heap histograms, and JFR recordings during pod termination for post-mortem analysis.

---

## Configuration (values)

Use `global.jfr` to enable JFR globally, and optionally override settings per-chart or per-deployment.

```yaml
# Global JFR configuration
global:
  jfr:
    enabled: false

# Chart-level or component-level overrides
jfr:
  image:
    registry: docker.io
    repository: busybox
    tag: latest
    
jfrDumpRootLocation: /opt/harness  # Base path for JFR dumps and symlinks
envType: default                    # Environment type label (e.g. prod, staging, dev)
lifecycleHooks: {}                  # Optional: provide custom lifecycle hooks (overrides JFR hooks)
shutdownHooksEnabled: false         # Enable simple shutdown hooks when JFR is disabled

# Java flags configuration
JAVA_REQUIRED_FLAGS: "-XX:+ExitOnOutOfMemoryError"
JAVA_ADDITIONAL_FLAGS: ""           # Additional JVM flags to append
```

When `global.jfr.enabled: true`, the templates automatically configure:
- Environment variables for pod/service identification
- Init container to set up JFR directories and symlinks
- Lifecycle hooks (postStart/preStop) for dump collection
- Volume mounts for persistent dump storage
- Java JVM flags for JFR recording

---

## Templates

### Environment Variables

Include in your deployment/statefulset container env section:

```yaml
env:
{{- include "harnesscommon.jfr.v1.renderEnvironmentVars" (dict "ctx" .) | indent 2 }}
```

Adds:
- `POD_NAME` – Kubernetes pod name (from metadata)
- `SERVICE_NAME` – Chart name
- `ENV_TYPE` – Environment type (from `envType` value)
- `JFR_DUMP_ROOT_LOCATION` – Base path for dumps

### Lifecycle Hooks

Include in your container spec:

```yaml
lifecycle:
{{- include "harnesscommon.v1.renderLifecycleHooks" (dict "ctx" .) | indent 2 }}
```

**postStart**: Creates JFR dump directories and symlink at `${JFR_DUMP_ROOT_LOCATION}/POD_NAME` pointing to the pod-specific dump location.

**preStop**: Collects diagnostics before pod termination:
- Thread dumps (10 retries)
- Heap histogram (10 retries)
- Native memory dump
- JFR recording dump
- Graceful JVM shutdown with 20s delay

If `lifecycleHooks` is set in values, uses that instead. If JFR is disabled but `shutdownHooksEnabled: true`, provides a simple 60s sleep preStop hook.

### Init Container

Include in your deployment/statefulset initContainers section:

```yaml
initContainers:
{{- include "harnesscommon.jfr.v1.initContainer" (dict "ctx" .) | indent 0 }}
```

Runs as root to:
1. Set permissions on dumps directory
2. Create pod-specific JFR directory structure
3. Create symlink at `${JFR_DUMP_ROOT_LOCATION}/POD_NAME`
4. Verify symlink before proceeding

### Volumes

Include in your deployment/statefulset volumes section:

```yaml
volumes:
{{- include "harnesscommon.jfr.v1.volumes" (dict "ctx" .) | indent 0 }}
```

Creates a `dumps` volume using hostPath `/var/dumps` with `DirectoryOrCreate` type.

### Volume Mounts

Include in your container volumeMounts section:

```yaml
volumeMounts:
{{- include "harnesscommon.jfr.v1.volumeMounts" (dict "ctx" .) | indent 0 }}
```

Mounts the `dumps` volume to `${JFR_DUMP_ROOT_LOCATION}/dumps`.

### Java Advanced Flags

Include in your JAVA_TOOL_OPTIONS or similar environment variable:

```yaml
env:
- name: JAVA_TOOL_OPTIONS
  value: {{ include "harnesscommon.jfr.v1.printJavaAdvancedFlags" (dict "ctx" .) }}
```

Generates JVM flags including:
- Required flags (default: `-XX:+ExitOnOutOfMemoryError`)
- Additional flags (from `JAVA_ADDITIONAL_FLAGS`)
- JFR recording flags when enabled:
  - `StartFlightRecording` with 12h max age, dump on exit
  - Flight recorder memory/chunk settings
  - Repository location using POD_NAME symlink
  - JFR module access and instrumentation settings

You can pass additional flags via the `additionalFlagsContext` parameter:

```yaml
value: {{ include "harnesscommon.jfr.v1.printJavaAdvancedFlags" (dict "ctx" . "additionalFlagsContext" "-Xmx2g -Xms2g") }}
```

---

## Examples

### Basic JFR configuration

Enable JFR for all Java services in the cluster:

```yaml
# values.yaml
global:
  jfr:
    enabled: true

jfr:
  image:
    registry: docker.io
    repository: busybox
    tag: latest
```

```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      initContainers:
      {{- include "harnesscommon.jfr.v1.initContainer" (dict "ctx" .) | indent 6 }}
      
      containers:
      - name: app
        env:
        {{- include "harnesscommon.jfr.v1.renderEnvironmentVars" (dict "ctx" .) | indent 8 }}
        - name: JAVA_TOOL_OPTIONS
          value: {{ include "harnesscommon.jfr.v1.printJavaAdvancedFlags" (dict "ctx" .) }}
        
        lifecycle:
        {{- include "harnesscommon.v1.renderLifecycleHooks" (dict "ctx" .) | indent 10 }}
        
        volumeMounts:
        {{- include "harnesscommon.jfr.v1.volumeMounts" (dict "ctx" .) | indent 8 }}
      
      volumes:
      {{- include "harnesscommon.jfr.v1.volumes" (dict "ctx" .) | indent 6 }}
```

### Custom JFR dump location

```yaml
jfrDumpRootLocation: /custom/jfr/path
envType: production

global:
  jfr:
    enabled: true
```

### Additional JVM tuning flags

```yaml
JAVA_ADDITIONAL_FLAGS: "-Xmx4g -Xms4g -XX:+UseG1GC -XX:MaxGCPauseMillis=200"

global:
  jfr:
    enabled: true
```

### Custom lifecycle hooks (override JFR)

If you need custom lifecycle behavior and want to disable the automatic JFR hooks:

```yaml
global:
  jfr:
    enabled: true  # Still provides env vars, volumes, init container

lifecycleHooks:
  postStart:
    exec:
      command: ["/bin/sh", "-c", "echo 'custom startup'"]
  preStop:
    exec:
      command: ["/bin/sh", "-c", "echo 'custom shutdown' && sleep 30"]
```

### Simple shutdown hook without JFR

For non-Java services or when JFR is not needed:

```yaml
global:
  jfr:
    enabled: false

shutdownHooksEnabled: true  # Adds 60s sleep preStop hook
```

---

## Dump Collection

When a pod terminates with JFR enabled, the preStop hook collects diagnostics to:

```
${JFR_DUMP_ROOT_LOCATION}/dumps/${SERVICE_NAME}/${ENV_TYPE}/${TIMESTAMP}/${POD_NAME}/
```

Contents:
- `restart` – Timestamp marker
- `begin` / `end` – Timing markers
- `thread-dump-attempt-*.txt` – Thread dumps (up to 10 attempts)
- `heap-histogram-attempt-*.txt` – Heap histograms (up to 10 attempts)
- `native-memory-dump.txt` – Native memory tracking output
- `jfr_done.txt` – JFR dump command output
- `mygclogfilename.gc` – GC log (if present)

Continuous JFR recordings are stored at:

```
${JFR_DUMP_ROOT_LOCATION}/dumps/${SERVICE_NAME}/${ENV_TYPE}/jfr_dumps/${POD_NAME}/
```

---

## Notes

- **Hostpath volume**: Dumps are stored on the node at `/var/dumps`. Ensure nodes have adequate space and appropriate access policies.
- **Security**: The init container runs as root (UID 0) to set permissions. The main container can run as non-root.
- **Symlink**: The `POD_NAME` symlink at `${JFR_DUMP_ROOT_LOCATION}/POD_NAME` allows JVM flags to reference a static path while dumps go to pod-specific directories.
- **Graceful shutdown**: The preStop hook adds a 20-second delay before sending SIGTERM, giving time for dump collection.
- **Retry logic**: Thread dumps and heap histograms retry up to 10 times, as `jcmd` can fail if the JVM is under heavy load.
- **Profile settings**: Uses `/opt/harness/profile.jfc` for JFR settings. Ensure your image includes this file or adjust the flag.

---

## References

- [Java Flight Recorder Overview](https://docs.oracle.com/javacomponents/jmc-5-4/jfr-runtime-guide/about.htm)
- [JFR Command Reference](https://docs.oracle.com/en/java/javase/17/docs/specs/man/jfr.html)
- [JFR Event Settings](https://sap.github.io/SapMachine/jfrevents/)
