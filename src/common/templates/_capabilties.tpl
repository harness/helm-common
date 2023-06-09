{{/*
Return the target Kubernetes version by default, can be overwritten by .Values.global.kubeVersion(needed for)
*/}}
{{- define "harnesscommon.capabilities.kubeVersion" -}}
{{- $providedKubeVersion := .Values.global.kubeVersion }}
{{- default .Capabilities.KubeVersion.Version $providedKubeVersion -}}
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