{{- define "harnesscommon.hpa.metrics.apiVersion" -}}
{{- if or .Values.autoscaling.targetMemory .Values.autoscaling.targetCPU }}
  metrics:
    {{- if .Values.autoscaling.targetMemory }}
    - type: Resource
      resource:
        name: memory
        {{- if semverCompare "<1.23-0" (include "harnesscommon.capabilities.kubeVersion" .) }}
        targetAverageUtilization: {{ .Values.autoscaling.targetMemory }}
        {{- else }}
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetMemory }}
        {{- end }}
    {{- end }}
    {{- if .Values.autoscaling.targetCPU }}
    - type: Resource
      resource:
        name: cpu
        {{- if semverCompare "<1.23-0" (include "harnesscommon.capabilities.kubeVersion" .) }}
        targetAverageUtilization: {{ .Values.autoscaling.targetCPU }}
        {{- else }}
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPU }}
        {{- end }}
    {{- end }}
  {{- end }}
{{- end -}}