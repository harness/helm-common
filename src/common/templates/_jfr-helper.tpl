{{/*
USAGE:
{{- include "harnesscommon.jfr.v1.renderEnvironmentVars" (dict "ctx" $) }}
*/}}
{{- define "harnesscommon.jfr.v1.renderEnvironmentVars" }}
{{- $ := .ctx }}
{{- if $.Values.global.jfr.enabled }}
- name: POD_NAME
  valueFrom:
    fieldRef:
      apiVersion: v1
      fieldPath: metadata.name
- name: SERVICE_NAME
  value: {{ $.Chart.Name }}
- name: ENV_TYPE
  value: {{ default "default" $.Values.envType }}
- name: JFR_DUMP_ROOT_LOCATION
  value: {{ default "/opt/harness" $.Values.jfrDumpRootLocation }}
{{- end }}
{{- end }}

{{/*
USAGE:
{{- include "harnesscommon.v1.renderLifecycleHooks" (dict "ctx" $) }}
*/}}
{{- define "harnesscommon.v1.renderLifecycleHooks" }}
{{- $ := .ctx }}
{{- if $.Values.lifecycleHooks }}
{{ include "harnesscommon.tplvalues.render" (dict "value" $.Values.lifecycleHooks "context" $) }}
{{- else if and $.Values.global.jfr $.Values.global.jfr.enabled }}
postStart:
  exec:
    command:
    - /bin/sh
    - -c
    - |
      mkdir -p ${JFR_DUMP_ROOT_LOCATION}/dumps/${SERVICE_NAME}/${ENV_TYPE}/jfr_dumps/${POD_NAME};
      rm -f ${JFR_DUMP_ROOT_LOCATION}/POD_NAME;
      ln -sf ${JFR_DUMP_ROOT_LOCATION}/dumps/${SERVICE_NAME}/${ENV_TYPE}/jfr_dumps/${POD_NAME} ${JFR_DUMP_ROOT_LOCATION}/POD_NAME;
preStop:
  exec:
    command:
    - /bin/sh
    - -c
    - |
      touch shutdown;
      sleep 20;
      ts=$(date '+%s');
      loc=${JFR_DUMP_ROOT_LOCATION}/dumps/${SERVICE_NAME}/${ENV_TYPE}/$ts/${POD_NAME};
      mkdir -p $loc; sleep 1; echo $ts > $loc/restart;
      echo $(date '+%s') > $loc/begin;
      PID=$(jps|grep -vi jps|awk '{ print $1}');
      #Copy GC log file
      cp mygclogfilename.gc $loc/;

      #Retry 10 times to take thread dump. Unsuccessful attempt has just 1 line with java process id in the output.
      for ((n=0;n<10;n++)); do
      jcmd $PID Thread.print -e > $loc/thread-dump-attempt-$n.txt;
      if [ $(wc -l < $loc/thread-dump-attempt-$n.txt) -gt 1 ]; then break; fi;
      done

      #10 retries to take heap histogram. Unsuccessful attempt has just 1 line with java process id in the output.
      for ((n=0;n<10;n++)); do
      jcmd $PID GC.class_histogram -all > $loc/heap-histogram-attempt-$n.txt;
      if [ $(wc -l < $loc/heap-histogram-attempt-$n.txt) -gt 1 ]; then break; fi;
      done

      jcmd $PID VM.native_memory  > $loc/native-memory-dump.txt;

      #Dump latest chunk of JFR recording
      jcmd $PID JFR.dump name=jfrRecording filename=${JFR_DUMP_ROOT_LOCATION}/dumps/${SERVICE_NAME}/${ENV_TYPE}/jfr_dumps/${POD_NAME}/container_termination_$(date +%Y_%m_%d_%H_%M_%S).jfr > $loc/jfr_done.txt

      echo $(date '+%s') > $loc/end
      kill -15 $PID;
{{- else if $.Values.shutdownHooksEnabled -}}
preStop:
  exec:
    command:
    - /bin/sh
    - '-c'
    - >
      touch shutdown;
      sleep 60;
{{- end }}
{{- end }}

{{/*
USAGE:
{{- include "harnesscommon.jfr.v1.volumes" (dict "ctx" $) }}
*/}}
{{- define "harnesscommon.jfr.v1.volumes" }}
{{- $ := .ctx }}
{{- if $.Values.global.jfr.enabled }}
- name: dumps
  hostPath:
    path: /var/dumps
    type: DirectoryOrCreate
{{- end }}
{{- end }}

{{/*
USAGE:
{{- include "harnesscommon.jfr.v1.volumeMounts" (dict "ctx" $) }}
*/}}
{{- define "harnesscommon.jfr.v1.volumeMounts" }}
{{- $ := .ctx }}
{{- if $.Values.global.jfr.enabled }}
- name: dumps
  mountPath: {{ default "/opt/harness" $.Values.jfrDumpRootLocation }}/dumps
{{- end }}
{{- end }}

{{/*
USAGE:
{{- include "harnesscommon.jfr.v1.printJavaAdvancedFlags" (dict "ctx" $) }}
*/}}
{{- define "harnesscommon.jfr.v1.printJavaAdvancedFlags" }}
{{- $ := .ctx }}
{{- $requiredFlags := default "-XX:+ExitOnOutOfMemoryError" $.Values.JAVA_REQUIRED_FLAGS }}
{{- $additionalFlags := default "" $.Values.JAVA_ADDITIONAL_FLAGS }}
{{- if .additionalFlagsContext }}
{{- $additionalFlags = .additionalFlagsContext }}
{{- end }}
{{- $javaAdvancedFlags := printf "%s %s" $requiredFlags $additionalFlags | trim }}
{{- $jfrDumpRootLocation := default "/opt/harness" $.Values.jfrDumpRootLocation }}
{{- $jfrFlags := printf "-XX:StartFlightRecording=disk=true,name=jfrRecording,maxage=12h,dumponexit=true,filename=%s/POD_NAME/jfr_dumponexit.jfr,settings=/opt/harness/profile.jfc -XX:FlightRecorderOptions=maxchunksize=20M,memorysize=20M,repository=%s/POD_NAME --add-reads jdk.jfr=ALL-UNNAMED -Dotel.instrumentation.redisson.enabled=false"  $jfrDumpRootLocation $jfrDumpRootLocation}}
{{- if $.Values.global.jfr.enabled }}
{{- $javaAdvancedFlags = printf "%s %s" $javaAdvancedFlags $jfrFlags }}
{{- end }}
{{- printf "%s" $javaAdvancedFlags }}
{{- end }}

{{/*
USAGE:
{{- include "harnesscommon.jfr.v1.initContainer" (dict "ctx" $) }}
*/}}
{{- define "harnesscommon.jfr.v1.initContainer" }}
{{- $ := .ctx }}
{{- $jfrDumpRootLocation := default "/opt/harness" $.Values.jfrDumpRootLocation }}
{{- if $.Values.global.jfr.enabled }}
- name: init-jfr-c03846b08a9d4837
  image: {{ include "common.images.image" (dict "imageRoot" $.Values.jfr.image "global" $.Values.global) }}
  securityContext:
    runAsUser: 0
    runAsNonRoot: false
  env:
  - name: POD_NAME
    valueFrom:
      fieldRef:
        apiVersion: v1
        fieldPath: metadata.name
  - name: SERVICE_NAME
    value: {{ $.Chart.Name }}
  - name: ENV_TYPE
    value: {{ default "default" $.Values.envType }}
  - name: JFR_DUMP_ROOT_LOCATION
    value: {{ $jfrDumpRootLocation }}
  command:
  - /bin/sh
  - -c
  - |
    echo "[JFR-Init] Starting JFR directory setup"
    echo "[JFR-Init] Pod: ${POD_NAME}"
    echo "[JFR-Init] Namespace: ${POD_NAMESPACE:-unknown}"
    echo "[JFR-Init] Service: ${SERVICE_NAME}"
    echo "[JFR-Init] Environment: ${ENV_TYPE}"

    JFR_DIR="${JFR_DUMP_ROOT_LOCATION}/dumps/${SERVICE_NAME}/${ENV_TYPE}/jfr_dumps/${POD_NAME}"
    SYMLINK_PATH="${JFR_DUMP_ROOT_LOCATION}/POD_NAME"

    echo "[JFR-Init] Setting permissions on ${JFR_DUMP_ROOT_LOCATION}/dumps"
    chmod -R 777 ${JFR_DUMP_ROOT_LOCATION}/dumps 2>/dev/null || true

    echo "[JFR-Init] Creating JFR directory: ${JFR_DIR}"
    mkdir -p ${JFR_DIR}

    echo "[JFR-Init] Creating symlink: ${SYMLINK_PATH} -> ${JFR_DIR}"
    if [ -L "${SYMLINK_PATH}" ] || [ -e "${SYMLINK_PATH}" ]; then
      echo "[JFR-Init] Removing existing symlink/file"
      rm -f ${SYMLINK_PATH}
    fi
    ln -s ${JFR_DIR} ${SYMLINK_PATH}

    if [ -L "${SYMLINK_PATH}" ]; then
      TARGET=$(readlink "${SYMLINK_PATH}")
      echo "[JFR-Init] ✓ Symlink verified: ${SYMLINK_PATH} -> ${TARGET}"
    else
      echo "[JFR-Init] ✗ ERROR: Symlink not created!"
      exit 1
    fi

    echo "[JFR-Init] ✓ JFR setup complete - JVM can now start with JFR"
  volumeMounts:
  {{- include "harnesscommon.jfr.v1.volumeMounts" (dict "ctx" $) | indent 2 }}
{{- end }}
{{- end }}
