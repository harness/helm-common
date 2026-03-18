{{/*
Create KEDA ScaledObject for event-driven autoscaling.

We set scaledobject.keda.sh/transfer-hpa-ownership: "true" so KEDA adopts any existing HPA for the same target (avoids conflict if both are enabled). See docs/KEDA.md (HPA coexistence).
Usage:
  Legacy (single deployment):
    {{- include "harnesscommon.keda.renderScaledObject" (dict "ctx" . "kind" "Deployment") }}

  With overrides:
    {{- include "harnesscommon.keda.renderScaledObject" (dict "ctx" . "kind" "Deployment" "nameOverride" "my-app-scaler" "targetRefNameOverride" "my-app") }}

  Multi-deployment with configPath:
    {{- include "harnesscommon.keda.renderScaledObject" (dict "ctx" . "kind" "Deployment" "nameOverride" "worker" "targetRefNameOverride" "worker" "configPath" .Values.worker) }}

Parameters:
  - ctx: Required. Root context (.)
  - kind: Optional. Target resource kind (default: Deployment). Use StatefulSet or custom CR that supports /scale.
  - nameOverride: Optional. ScaledObject resource name (default: chart fullname).
  - targetRefNameOverride: Optional. scaleTargetRef.name (default: same as name logic).
  - configPath: Optional. Values path for this deployment (e.g. .Values.worker). If not set, uses $.Values.

Values (under keda or configPath.keda):
  - enabled: Enable KEDA ScaledObject creation.
  - scaledObject.minReplicaCount, maxReplicaCount, pollingInterval, cooldownPeriod, etc.
  - scaledObject.triggers: Required when enabled. List of KEDA trigger specs (passthrough).
  - scaledObject.fallback, scaledObject.advanced: Optional. Passthrough.
  - scaledObject.annotations: Optional. Metadata annotations for the ScaledObject.
*/}}
{{- define "harnesscommon.keda.renderScaledObject" -}}
{{- $ := .ctx }}
{{- $serviceName := default $.Chart.Name $.Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- $scaledObjectName := $serviceName }}
{{- if .nameOverride }}
  {{- $scaledObjectName = .nameOverride }}
{{- end }}
{{- $targetRefName := default $scaledObjectName .targetRefNameOverride }}

{{/* Config source: configPath if provided, else root $.Values */}}
{{- $config := $.Values }}
{{- if .configPath }}
  {{- $config = .configPath }}
{{- end }}

{{/* KEDA enabled: global.keda.enabled OR config.keda.enabled */}}
{{- $kedaEnabled := false }}
{{- if and $.Values.global.keda $.Values.global.keda.enabled }}
  {{- $kedaEnabled = true }}
{{- end }}
{{- if and $config.keda $config.keda.enabled }}
  {{- $kedaEnabled = true }}
{{- end }}

{{- if and $kedaEnabled $config.keda.scaledObject $config.keda.scaledObject.triggers }}
{{- $so := $config.keda.scaledObject }}
{{- $labelsFunction := printf "%s.labels" (default $.Chart.Name $.Values.nameOverride) }}
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: {{ $scaledObjectName | trunc 63 | trimSuffix "-" }}
  namespace: {{ include "harnesscommon.names.namespace" $ }}
  labels:
    {{- include $labelsFunction $ | nindent 4 }}
    {{- if $.Values.global.commonLabels }}
    {{- include "harnesscommon.tplvalues.render" (dict "value" $.Values.global.commonLabels "context" $) | nindent 4 }}
    {{- end }}
  annotations:
    {{- /* Allow KEDA to take over an existing HPA for this target if both are present (avoids conflict) */}}
    scaledobject.keda.sh/transfer-hpa-ownership: "true"
    {{- if $.Values.global.commonAnnotations }}
    {{- include "harnesscommon.tplvalues.render" (dict "value" $.Values.global.commonAnnotations "context" $) | nindent 4 }}
    {{- end }}
    {{- if $so.annotations }}
    {{- include "harnesscommon.tplvalues.render" (dict "value" $so.annotations "context" $) | nindent 4 }}
    {{- end }}
spec:
  scaleTargetRef:
    apiVersion: {{ default "apps/v1" (dig "scaleTargetRef" "apiVersion" "apps/v1" $so) }}
    kind: {{ or (dig "scaleTargetRef" "kind" "" $so) (.kind | default "Deployment") }}
    name: {{ $targetRefName }}
    {{- if and $so.scaleTargetRef $so.scaleTargetRef.envSourceContainerName }}
    envSourceContainerName: {{ $so.scaleTargetRef.envSourceContainerName }}
    {{- end }}

  {{/* Replica and timing: precedence global < root/configPath */}}
  {{- $minReplicaCount := 0 }}
  {{- $maxReplicaCount := 100 }}
  {{- $pollingInterval := 30 }}
  {{- $cooldownPeriod := 300 }}
  {{- $initialCooldownPeriod := 0 }}
  {{- if and $.Values.global.keda $.Values.global.keda.scaledObject }}
    {{- if hasKey $.Values.global.keda.scaledObject "minReplicaCount" }}{{- $minReplicaCount = $.Values.global.keda.scaledObject.minReplicaCount }}{{- end }}
    {{- if hasKey $.Values.global.keda.scaledObject "maxReplicaCount" }}{{- $maxReplicaCount = $.Values.global.keda.scaledObject.maxReplicaCount }}{{- end }}
    {{- if hasKey $.Values.global.keda.scaledObject "pollingInterval" }}{{- $pollingInterval = $.Values.global.keda.scaledObject.pollingInterval }}{{- end }}
    {{- if hasKey $.Values.global.keda.scaledObject "cooldownPeriod" }}{{- $cooldownPeriod = $.Values.global.keda.scaledObject.cooldownPeriod }}{{- end }}
    {{- if hasKey $.Values.global.keda.scaledObject "initialCooldownPeriod" }}{{- $initialCooldownPeriod = $.Values.global.keda.scaledObject.initialCooldownPeriod }}{{- end }}
  {{- end }}
  {{- if $so.minReplicaCount }}
    {{- $minReplicaCount = $so.minReplicaCount }}
  {{- end }}
  {{- if $so.maxReplicaCount }}
    {{- $maxReplicaCount = $so.maxReplicaCount }}
  {{- end }}
  {{- if $so.pollingInterval }}
    {{- $pollingInterval = $so.pollingInterval }}
  {{- end }}
  {{- if $so.cooldownPeriod }}
    {{- $cooldownPeriod = $so.cooldownPeriod }}
  {{- end }}
  {{- if $so.initialCooldownPeriod }}
    {{- $initialCooldownPeriod = $so.initialCooldownPeriod }}
  {{- end }}

  minReplicaCount: {{ $minReplicaCount }}
  maxReplicaCount: {{ $maxReplicaCount }}
  pollingInterval: {{ $pollingInterval }}
  cooldownPeriod: {{ $cooldownPeriod }}
  {{- if ne $initialCooldownPeriod 0 }}
  initialCooldownPeriod: {{ $initialCooldownPeriod }}
  {{- end }}
  {{- if hasKey $so "idleReplicaCount" }}
  idleReplicaCount: {{ $so.idleReplicaCount }}
  {{- end }}

  {{- if $so.fallback }}
  fallback:
    {{- include "harnesscommon.tplvalues.render" (dict "value" $so.fallback "context" $) | nindent 4 }}
  {{- end }}

  {{- if $so.advanced }}
  advanced:
    {{- include "harnesscommon.tplvalues.render" (dict "value" $so.advanced "context" $) | nindent 4 }}
  {{- end }}

  triggers:
    {{- include "harnesscommon.tplvalues.render" (dict "value" $so.triggers "context" $) | nindent 4 }}
{{- end }}
{{- end }}
