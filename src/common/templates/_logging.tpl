{{/*
Set File Logging Config
Usage example:
{{- include "harnesscommon.logging.setFileLogging" . }}
*/}}
{{- define "harnesscommon.logging.setFileLogging" -}}

{{- $local := .Values.fileLogging }}
{{- $global := .Values.global.fileLogging }}
{{- $globalCopy := deepCopy $global }}
{{- $fileLoggingConfig := $globalCopy }}
{{- if $local }}
    {{- $fileLoggingConfig = deepCopy $local | mergeOverwrite $globalCopy }}
{{- end }}
{{- if $fileLoggingConfig.enabled }}
    {{- println "FILE_LOGGING_ENABLED: 'true'" }}
    {{- if $fileLoggingConfig.logFilename }}
        {{- printf "LOG_FILENAME: '%s'\n" $fileLoggingConfig.logFilename }}
    {{- end }}
    {{- if $fileLoggingConfig.maxFileSize }}
        {{- printf "LOG_MAX_FILE_SIZE: '%s'\n" $fileLoggingConfig.maxFileSize }}
    {{- end }}
    {{- if $fileLoggingConfig.maxBackupFileCount }}
        {{- printf "LOG_MAX_FILE_COUNT: '%v'\n" $fileLoggingConfig.maxBackupFileCount }}
    {{- end }}
    {{- if $fileLoggingConfig.totalFileSizeCap }}
        {{- printf "LOG_TOTAL_FILE_SIZE_CAP: '%s'\n" $fileLoggingConfig.totalFileSizeCap }}
    {{- end }}
{{- end }}
{{- end -}}