{{/*
BackendTLSPolicy template for Gateway API
Configures TLS settings for connections from the Gateway to backend Services

USAGE (automatically called by renderIngress when gatewayAPI is enabled):
Define policies in your consuming chart's values.yaml under ingress.backendTLSPolicies:

ingress:
  backendTLSPolicies:
    - name: my-backend-tls         # optional, auto-generated if omitted
      targetRef:
        name: my-service           # required: target Service name
        port: 8443                 # optional: specific port
      validation:
        hostname: my-service.ns.svc.cluster.local  # required: expected backend cert hostname
        caCertificateRefs:         # option 1: explicit CA certs
          - name: backend-ca
            group: ""              # optional, defaults to ""
            kind: Secret           # optional, defaults to Secret
        wellKnownCACertificates: "" # option 2: "System" to use system trust store
*/}}
{{- define "harnesscommon.v2.renderBackendTLSPolicy" }}
{{- $ := .ctx }}
{{- $ingress := $.Values.ingress }}
{{- if .ingress -}}
    {{- $ingress = .ingress }}
{{- end }}
{{- if and (dig "gatewayAPI" "enabled" false $.Values.global) (dig "ingress" "enabled" false $.Values.global) -}}
{{- $policies := dig "backendTLSPolicies" list $ingress }}
{{- range $index, $policy := $policies }}
{{- $policyName := dig "name" ((cat (coalesce $ingress.name $.Values.nameOverride $.Chart.Name | trunc 63 | trimSuffix "-") "-backend-tls-" $index) | nospace) $policy }}
---
apiVersion: gateway.networking.k8s.io/v1alpha3
kind: BackendTLSPolicy
metadata:
  name: {{ $policyName }}
  namespace: {{ $.Release.Namespace }}
  {{- if $.Values.global.commonLabels }}
  labels:
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonLabels "context" $ ) | nindent 4 }}
  {{- end }}
  {{- if or $.Values.global.commonAnnotations (dig "annotations" false $policy) }}
  annotations:
    {{- if $.Values.global.commonAnnotations }}
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonAnnotations "context" $ ) | nindent 4 }}
    {{- end }}
    {{- if $policy.annotations }}
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $policy.annotations "context" $ ) | nindent 4 }}
    {{- end }}
  {{- end }}
spec:
  targetRefs:
    - group: ""
      kind: Service
      name: {{ $policy.targetRef.name }}
      {{- if $policy.targetRef.port }}
      sectionName: {{ $policy.targetRef.port | quote }}
      {{- end }}
  validation:
    hostname: {{ $policy.validation.hostname | quote }}
    {{- if $policy.validation.caCertificateRefs }}
    caCertificateRefs:
      {{- range $ref := $policy.validation.caCertificateRefs }}
      - name: {{ $ref.name }}
        group: {{ $ref.group | default "" | quote }}
        kind: {{ $ref.kind | default "Secret" }}
      {{- end }}
    {{- end }}
    {{- if $policy.validation.wellKnownCACertificates }}
    wellKnownCACertificates: {{ $policy.validation.wellKnownCACertificates | quote }}
    {{- end }}
{{- end }}
{{- end }}
{{- end }}
