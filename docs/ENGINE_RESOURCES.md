# Harness Engine resources

`harnesscommon.engine.renderResources` renders Harness Engine custom resources
(`engine.harness.io/v1alpha1`) from your chart's values. The CRD itself is installed by the
`engine-operator` chart; this template only renders CRs.

## Usage

Add `templates/engine-resources.yaml` to your chart:

```yaml
{{- include "harnesscommon.engine.renderResources" (dict "ctx" .) }}
```

Declare resources in values:

```yaml
engineResources:
  schedules:
    nightly-cleanup:            # CR name: <release name>-nightly-cleanup
      enabled: true             # optional; only false skips the entry
      spec:                     # required; copied verbatim, no defaults added
        namespace: pipeline
        identifier: nightly-cleanup
        cronExpr: "0 3 * * *"
        invocation:
          queue: pipeline
          action: cleanup
```

Every CR is created in the release namespace.

## Per-environment overrides

Resources are a map keyed by name, so an environment values file (for example
`harness-helm-overrides/services/<service>/<service>_<env>.yaml`) can:

```yaml
engineResources:
  schedules:
    nightly-cleanup:
      spec:
        cronExpr: "*/10 * * * *"   # modify
    legacy-sync:
      enabled: false               # disable
    my-env-only:                   # add
      spec: { ... }
```

Use `enabled: false` to remove an inherited entry. The overrides merge normalizes `null` to `{}`, so
`<name>: null` leaves an inherited entry unchanged, and on a new entry it fails with "spec is
required".

## Rendering rules

- No defaults are injected. Optional fields such as `timeZone` or `state` appear only if you set them.
- An enabled entry without `spec` (or with `spec: {}`) fails rendering. The template does not
  check the spec's contents. The API server validates them against the CRD when the release is
  applied: `namespace`, `identifier`, `cronExpr`, `invocation.queue` and `invocation.action` are
  required. A rejected CR fails the whole release.
- Entries render sorted by name.
- If the cluster does not serve `engine.harness.io/v1alpha1/Schedule`, nothing is rendered. With
  `helm template`, pass `--api-versions engine.harness.io/v1alpha1/Schedule`.
- The CR is named `<release name>-<name>`, so two releases in one namespace can use the same key.
  Rendering fails if that name exceeds 253 characters. The engine identifies a schedule by
  `spec.namespace` + `spec.identifier`, so keep the `identifier` unique within each engine namespace.
