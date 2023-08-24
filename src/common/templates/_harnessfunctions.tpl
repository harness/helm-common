{{/* vim: set filetype=mustache: */}}
{{/*
Renders a value that contains template.
Usage:
{{ include "harnesscommon.harnessfunctions.java17flags" (dict "context" $) }}
*/}}
{{- define "harnesscommon.harnessfunctions.java17flags" -}}
{{- $java17flags := "--illegal-access=debug --add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED --add-opens java.base/java.nio=ALL-UNNAMED --add-opens java.base/java.util.concurrent.atomic=ALL-UNNAMED --add-opens java.base/java.time=ALL-UNNAMED --add-opens java.base/java.io=ALL-UNNAMED --add-opens java.base/java.lang.invoke=ALL-UNNAMED --add-opens java.base/java.math=ALL-UNNAMED --add-opens java.base/java.nio.file=ALL-UNNAMED --add-opens java.base/java.util.concurrent=ALL-UNNAMED --add-opens java.xml/com.sun.org.apache.xpath.internal=ALL-UNNAMED --add-opens=java.base/java.lang.reflect=ALL-UNNAMED --add-exports java.xml/com.sun.org.apache.xerces.internal.parsers=ALL-UNNAMED --add-exports java.base/sun.nio.ch=ALL-UNNAMED" }}
{{- if .context.Values.java17flags }}
{{- $java17flags = .context.Values.java17flags }}
{{- end }}
{{- printf "JAVA_17_FLAGS: %s" $java17flags -}}
{{- end -}}