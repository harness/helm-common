{{/*
USAGE:
lifecycle: {{- include "harnesscommon.v1.renderLifecycleHooks" (dict "ctx" $) | nindent 10 }}
*/}}
{{- define "harnesscommon.v1.renderLifecycleHooks" -}}
{{- $ := .ctx -}}
{{/*
  Check if lifecycle hooks should be disabled:
  1. If global.lifecycleHooks.disable is true, don't add hooks
  2. Else if service-level lifecycleHooks.disable is true, don't add hooks
*/}}
{{- $disableHooks := false -}}
{{- if $.Values.global.lifecycleHooks.disable -}}
  {{- $disableHooks = true -}}
{{- else if $.Values.lifecycleHooks.disable -}}
  {{- $disableHooks = true -}}
{{- end -}}

{{- if not $disableHooks -}}
  {{/*
    Priority order for lifecycle hooks:
    1. Service-level lifecycleHooks configuration
    2. Global-level lifecycleHooks configuration
    3. Default configuration
  */}}
  {{- if $.Values.lifecycleHooks.spec -}}
    {{/* Use service-level configuration */}}
    {{- include "harnesscommon.tplvalues.render" (dict "value" $.Values.lifecycleHooks.spec "context" $) -}}
  {{- else if $.Values.global.lifecycleHooks.spec -}}
    {{/* Use global-level configuration */}}
    {{- include "harnesscommon.tplvalues.render" (dict "value" $.Values.global.lifecycleHooks.spec "context" $) -}}
  {{- else if and (hasKey $.Values.global "jfr") (hasKey $.Values.global.jfr "enabled") ($.Values.global.jfr.enabled) -}}
  postStart:
    exec:
      command: 
      - /bin/sh
      - -c
      - |
        mkdir -p ${JFR_DUMP_ROOT_LOCATION}/dumps/${SERVICE_NAME}/${ENV_TYPE}/jfr_dumps/${POD_NAME};
        ln -s ${JFR_DUMP_ROOT_LOCATION}/dumps/${SERVICE_NAME}/${ENV_TYPE}/jfr_dumps/${POD_NAME} ${JFR_DUMP_ROOT_LOCATION}/POD_NAME ;
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
  {{- else -}}
  preStop:
    exec:
      command:
      - /bin/sh
      - '-c'
      - >
        touch shutdown;
        sleep 60;
  {{- end -}}
{{- end -}}
{{- end -}}
