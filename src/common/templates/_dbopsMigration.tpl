{{/*
Returns "true" if dbops helm migration is enabled, "" otherwise.
Local dbopsHelmMigration.enabled takes precedence over global.dbopsHelmMigration.enabled.

Usage:
{{ include "harnesscommon.dbopsMigration.enabled" . }}
*/}}
{{- define "harnesscommon.dbopsMigration.enabled" -}}
{{- $globalEnabled := false }}
{{- if and (hasKey .Values.global "dbopsHelmMigration") (hasKey .Values.global.dbopsHelmMigration "enabled") }}
  {{- $globalEnabled = .Values.global.dbopsHelmMigration.enabled }}
{{- end }}
{{- $migrationsEnabled := $globalEnabled }}
{{- if hasKey .Values "dbopsHelmMigration" }}
  {{- if hasKey .Values.dbopsHelmMigration "enabled" }}
    {{- $migrationsEnabled = .Values.dbopsHelmMigration.enabled }}
  {{- end }}
{{- end }}
{{- if $migrationsEnabled }}true{{- end }}
{{- end }}

{{/*
Renders wait-for + dbops-helm-migrate init containers when dbops helm migration is enabled.
The template is DB-agnostic — callers inject their own database env vars via envIncludes.

Usage:
{{ include "harnesscommon.dbopsMigration.initContainers" (dict "root" . "envIncludes" (list
  (include "harnesscommon.dbv3.mongoEnv" (dict "ctx" $ "database" "dbservice"))
  (include "harnesscommon.dbv3.mongoConnectionEnv" (dict "ctx" $ "database" "dbservice" "connectionURIVariableName" "MONGO_URI"))
)) }}

Params:
  - root - Object - Required. Helm root context (.)
  - envIncludes - List - Required. List of rendered env var YAML strings to inject into the init container.

Requires these values in the consuming chart:
  .Values.dbopsHelmMigration.migrator.scheme
  .Values.dbopsHelmMigration.migrator.serviceName
  .Values.dbopsHelmMigration.migrator.servicePort
  .Values.dbopsHelmMigration.migrator.healthPath
  .Values.dbopsHelmMigration.migrator.applyPath
  .Values.dbopsHelmMigration.migrator.operationsPath
  .Values.dbopsHelmMigration.targets[]  (name, dbUrlEnv, usernameEnv?, passwordEnv?)
*/}}
{{- define "harnesscommon.dbopsMigration.initContainers" -}}
{{- $root := .root }}
{{- if eq (include "harnesscommon.dbopsMigration.enabled" $root) "true" }}
{{ include "harnesscommon.initContainer.waitForContainer" (dict "root" $root "appName" $root.Values.dbopsHelmMigration.migrator.serviceName) }}
- name: dbops-helm-migrate
  image: {{ include "common.images.image" (dict "imageRoot" $root.Values.global.waitForInitContainer.image "global" $root.Values.global) }}
  imagePullPolicy: {{ $root.Values.global.waitForInitContainer.image.pullPolicy | default "IfNotPresent" }}
  securityContext:
    {{- toYaml $root.Values.global.waitForInitContainer.containerSecurityContext | nindent 4 }}
  resources:
    {{- toYaml $root.Values.global.waitForInitContainer.resources | nindent 4 }}
  env:
    {{- range .envIncludes }}
    {{- . | indent 4 }}
    {{- end }}
    - name: SMP_VERSION
      valueFrom:
        configMapKeyRef:
          name: global-smp-config
          key: SMP_VERSION
          optional: true
    - name: PREVIOUS_SMP_VERSION
      valueFrom:
        configMapKeyRef:
          name: global-smp-config
          key: PREVIOUS_SMP_VERSION
          optional: true
  command:
    - /bin/sh
    - -c
    - |
      set -euo pipefail

      MIGRATOR_BASE="{{ $root.Values.dbopsHelmMigration.migrator.scheme }}://{{ $root.Values.dbopsHelmMigration.migrator.serviceName }}:{{ $root.Values.dbopsHelmMigration.migrator.servicePort }}"
      HEALTH_URL="${MIGRATOR_BASE}{{ $root.Values.dbopsHelmMigration.migrator.healthPath }}"
      APPLY_URL="${MIGRATOR_BASE}{{ $root.Values.dbopsHelmMigration.migrator.applyPath }}"
      OPERATIONS_BASE_URL="${MIGRATOR_BASE}{{ $root.Values.dbopsHelmMigration.migrator.operationsPath }}"
      SMP_VERSION="${SMP_VERSION:-}"
      PREVIOUS_SMP_VERSION="${PREVIOUS_SMP_VERSION:-}"

      echo "Waiting for migrator at: ${HEALTH_URL}"
      i=0
      until curl -sf "${HEALTH_URL}" >/dev/null 2>&1; do
        i=$((i+1))
        if [ "$i" -gt 300 ]; then
          echo "ERROR: migrator not healthy after 10 minutes" >&2
          exit 1
        fi
        sleep 2
      done

      tmp_headers="$(mktemp)"
      tmp_body="$(mktemp)"
      trap 'rm -f "$tmp_headers" "$tmp_body" || true' EXIT

      json_escape() {
        printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr -d '\n\r'
      }

      header_val() {
        name="$1"
        grep -i "^${name}:" "$tmp_headers" | head -n 1 | sed -E 's/^[^:]*:[[:space:]]*//' | tr -d '\r'
      }

      apply_and_wait() {
        svc="$1"; targets_json="$2"

        BODY='{"service":"'"$svc"'","targets":'"$targets_json"
        if [ -n "$SMP_VERSION" ]; then
          BODY="${BODY},\"smpVersion\":\"${SMP_VERSION}\""
        fi
        if [ -n "$PREVIOUS_SMP_VERSION" ]; then
          BODY="${BODY},\"previousSmpVersion\":\"${PREVIOUS_SMP_VERSION}\""
        fi
        BODY="${BODY}}"

        : >"$tmp_headers"; : >"$tmp_body"
        http_code="$(
          curl -sS \
            --connect-timeout 5 \
            --max-time 30 \
            -D "$tmp_headers" \
            -o "$tmp_body" \
            -w '%{http_code}' \
            -X POST "$APPLY_URL" \
            -H "Content-Type: application/json" \
            -d "$BODY"
        )" || http_code="000"

        case "$http_code" in
          202) ;;
          400)
            echo "ERROR: /apply bad request (service=$svc)" >&2
            cat "$tmp_body" >&2 || true
            exit 1
            ;;
          404)
            echo "ERROR: bundle not found in migrator image (service=$svc)" >&2
            cat "$tmp_body" >&2 || true
            exit 1
            ;;
          *)
            echo "ERROR: /apply failed (http=$http_code service=$svc)" >&2
            cat "$tmp_body" >&2 || true
            exit 1
            ;;
        esac

        operation_id="$(tr -d '\r\n' < "$tmp_body")"
        if [ -z "$operation_id" ]; then
          echo "ERROR: /apply returned 202 but body did not contain an operationId" >&2
          exit 1
        fi
        echo "Migration started, operationId=$operation_id"

        poll_url="${OPERATIONS_BASE_URL}/${operation_id}"
        ra="$(header_val Retry-After || true)"; [ -z "$ra" ] && ra=2
        sleep "$ra"

        while true; do
          : >"$tmp_headers"; : >"$tmp_body"
          poll_code="$(curl -sS \
            --connect-timeout 5 \
            --max-time 15 \
            -D "$tmp_headers" \
            -o "$tmp_body" \
            -w '%{http_code}' \
            "$poll_url")" || poll_code="000"

          case "$poll_code" in
            200) echo "Migration succeeded:"; cat "$tmp_body" || true; echo; return 0 ;;
            202)
              ra="$(header_val Retry-After || true)"; [ -z "$ra" ] && ra=2
              sleep "$ra"
              ;;
            000) sleep 2 ;;
            *)
              echo "ERROR: migration failed (http=$poll_code service=$svc)" >&2
              cat "$tmp_body" >&2 || true
              exit 1
              ;;
          esac
        done
      }

      echo "Applying migrations: service={{ $root.Chart.Name }}"
      TARGETS='[{{- range $i, $t := $root.Values.dbopsHelmMigration.targets }}{{- if $i }},{{- end }}{"name":"{{ $t.name }}","dbUrl":"'"$(json_escape "${{ $t.dbUrlEnv }}")"'"{{- if $t.usernameEnv }},"username":"'"$(json_escape "${{ $t.usernameEnv }}")"'"{{- end }}{{- if $t.passwordEnv }},"password":"'"$(json_escape "${{ $t.passwordEnv }}")"'"{{- end }}}{{- end }}]'
      apply_and_wait "{{ $root.Chart.Name }}" "$TARGETS"
{{- end }}
{{- end }}
