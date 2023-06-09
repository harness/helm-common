{{/*
Return the target Kubernetes version
*/}}
{{- define "harnesscommon.capabilities.kubeVersion" -}}
{{- $providedKubeVersion := pluck .Values.global.kubeVersion | first  }}
{{- default $providedKubeVersion .Capabilities.KubeVersion.Version -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for Horizontal Pod Autoscaler.
*/}}
{{- define "harnesscommon.capabilities.hpa.apiVersion" -}}
{{- if semverCompare "<1.23-0" (include "harnesscommon.capabilities.kubeVersion" .context) -}}
{{- print "autoscaling/v2beta2" -}}
{{- else -}}
{{- print "autoscaling/v2" -}}
{{- end -}}
{{- end -}}