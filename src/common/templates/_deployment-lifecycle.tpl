{{/*
USAGE:
{{- include "harnesscommon.v1.renderLifecycleHooks" (dict "ctx" $) }}
A JFR hook can be automatically added if JFR is enabled
*/}}
{{- define "harnesscommon.v1.renderLifecycleHooks" }}
{{- $ := .ctx }}
{{- if hasKey $.Values "lifecycleHooks" }}
{{ include "harnesscommon.tplvalues.render" (dict "value" $.Values.lifecycleHooks "context" $) }}
{{- else if $.Values.global.jfr.enabled }}
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
      ## The pod is out of service at this point in Endpoints (nominally).  Allow time before we start signally process
      ## stops and termination via the shutdown file.
      sleep {{- default "30" (default dict $.Values.lifecycleHooks).terminationTime }};
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

      ## Dump native memory for analysis
      jcmd $PID VM.native_memory  > $loc/native-memory-dump.txt;

      #Dump latest chunk of JFR recording
      jcmd $PID JFR.dump name=jfrRecording filename=${JFR_DUMP_ROOT_LOCATION}/dumps/${SERVICE_NAME}/${ENV_TYPE}/jfr_dumps/${POD_NAME}/container_termination_$(date +%Y_%m_%d_%H_%M_%S).jfr > $loc/jfr_done.txt

      echo $(date '+%s') > $loc/end

      ## Once JFR is caught, drop maintenace file & sleep final for grace period & complete termination
      touch shutdown;
      sleep {{- default "30" (default dict $.Values.lifecycleHooks).terminationGraceTime }};
      ## Send SIGTERM which starts JVM Shutdown hooks & upon completion will exit
      kill -15 $PID;
{{- else }}
{{/*
This is the default lifecycle hook that should be applied to services.  It adds shutdown delays to allow connection
draining via maintenance checks on the shutdown file.
*/}}
preStop:
  exec:
    command:
    - /bin/sh
    - -c
    - |
      ## The pod is out of service at this point in Endpoints (nominally).  Allow time before we stop processing async
      ## and trigger termination or processes via the shutdown file.
      sleep {{- default "30" (default dict $.Values.lifecycleHooks).terminationTime }};
      touch shutdown;
      sleep {{- default "30" (default dict $.Values.lifecycleHooks).terminationGraceTime }};
{{- end }}
{{- end }}

