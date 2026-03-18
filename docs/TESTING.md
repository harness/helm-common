# Testing the harness-common library chart

The library chart cannot be rendered alone (it only provides partial templates). We test it by rendering a **consumer test chart** that depends on `harness-common` and invokes the library helpers with different value sets.

## Strategy

1. **Template smoke tests** – Run `helm template` with scenario value files for every top-level manifest helper: HPA, PDB, KEDA (ScaledObject + TriggerAuthentication), Ingress, and VirtualService. Ensures no template errors and produces valid YAML. Fast and catches regressions.
2. **helm-unittest** – Assert on rendered output (document count, kind, spec fields) for HPA, PDB, and KEDA. Test files live in `ci/test-chart/tests/*_test.yaml`. Run with `helm unittest ci/test-chart` (requires the [helm-unittest](https://github.com/helm-unittest/helm-unittest) plugin).
3. **Lint** – Existing `ct lint` on the library chart (syntax, Chart.yaml).

## Local quick check

From repo root, using the consumer chart under `ci/test-chart`:

```bash
# Resolve library dependency (file reference to ../../src/common)
helm dependency update ci/test-chart

# Smoke test: render with each scenario (must exit 0 and produce valid YAML)
helm template test-release ci/test-chart -f ci/test-chart/ci-values/hpa.yaml --validate 2>/dev/null | head -20
helm template test-release ci/test-chart -f ci/test-chart/ci-values/pdb.yaml --validate 2>/dev/null | head -20
helm template test-release ci/test-chart -f ci/test-chart/ci-values/keda.yaml --validate 2>/dev/null | head -20
helm template test-release ci/test-chart -f ci/test-chart/ci-values/ingress.yaml --validate 2>/dev/null | head -20
helm template test-release ci/test-chart -f ci/test-chart/ci-values/virtualservice.yaml --validate 2>/dev/null | head -20
```

Or run the script used in CI (template scenarios + helm-unittest if the plugin is installed):

```bash
./ci/run-tests.sh
```

**Pre-commit:** If you use [pre-commit](https://pre-commit.com/), the config in `.pre-commit-config.yaml` includes a `helm-common-tests` hook that runs this script on every commit, so template and unit test failures are caught before you push.

To run only helm-unittest:

```bash
helm dependency update ci/test-chart
helm unittest ci/test-chart
```

## Test chart layout

- **ci/test-chart/** – Minimal chart that depends on `harness-common` via `file://../../src/common`.
- **ci/test-chart/templates/** – One file per feature (HPA, PDB, KEDA ScaledObject, KEDA TriggerAuthentication, Ingress, VirtualService) that includes the library helper. Renders only when the corresponding values enable that feature.
- **ci/test-chart/ci-values/*.yaml** – Scenario value files used in CI to exercise HPA, PDB, KEDA, Ingress, VirtualService.

The test chart defines `harness-common-test.labels` and `harness-common-test.selectorLabels` (delegating to the library) so the library’s expectations for the consuming chart are satisfied. Its **base values** (`ci/test-chart/values.yaml`) set `global.pdb`, `global.autoscaling`, `global.keda`, `global.ingress`, `global.istio`, and top-level `pdb`/`autoscaling`/`keda`/`ingress`/`virtualService` to safe defaults so that when only one scenario is enabled (e.g. HPA), other templates do not see nil and fail.

## Adding a new scenario

1. Add a value file under `ci/test-chart/ci-values/` (e.g. `myfeature.yaml`) that enables the feature.
2. If the feature needs a dedicated template, add `ci/test-chart/templates/myfeature.yaml` that includes the library helper.
3. Add the scenario to `ci/run-tests.sh` (in the "Rendering scenarios" section).
4. Add a helm-unittest suite under `ci/test-chart/tests/` (e.g. `myfeature_test.yaml`) with `values`, `templates`, and `tests` asserting document count, `isKind`, and important `spec` fields.

## CI (GitHub Actions)

- **Lint** – `ct lint` on `src/common` (existing).
- **Template tests** – Job that runs `ci/run-tests.sh`: dependency update + `helm template` for each scenario. Fails if any template fails or output is invalid.

Running tests on every PR gives confidence that new features and changes do not break existing behavior.
