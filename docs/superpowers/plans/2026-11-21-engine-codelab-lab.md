# Engine codelab lab Implementation Plan

> **For agentic workers.** Use the `superpowers:subagent-driven-development` skill, which is recommended, or `superpowers:executing-plans` to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal.** Run the Kotlin FHIR Engine codelab on a headless Heropa VM with a browser editor, an auto-rebuilt web app and a HAPI FHIR server.

**Architecture.** A copy of the SDC lab at `/home/kiarie/Desktop/Heropa-SDC-Codelab/`, adapted. Four containers (`workspace`, `hapi`, `seed`, `nginx`). nginx serves the editor, the Wasm app and HAPI at `/fhir/` on one sslip.io address.

**Tech Stack.** Docker Compose, nginx 1.27, code-server 4.145.2, Temurin JDK 21, Gradle with Kotlin Multiplatform Wasm, HAPI FHIR v8.12.0-2, bash.

**Spec.** `docs/superpowers/specs/2026-11-20-engine-codelab-lab-design.md`

## Global Constraints

- Codelab pin `697412d04157980fc24eb3fbb2e8e5c479b0f0ee` of `https://github.com/ohs-foundation/kotlin-fhir-engine.git`.
- Build task `:shared:wasmJsBrowserDevelopmentExecutableDistribution`, output `shared/build/dist/wasmJs/developmentExecutable/`.
- Compose project `engine-codelab`. Containers `engine-workspace`, `engine-hapi`, `engine-seed`, `engine-nginx`. Image `engine-codelab-workspace:local`.
- `/app/` and `/preview/` carry `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`.
- Documentation prose and human-readable comments carry no em dashes, semicolons or colons. Text quoted from the published codelab keeps its punctuation.
- The repository is not a git repository, so tasks end with a verification and no commit.
- Never copy `.env`, `certs/` or `letsencrypt/` from the SDC lab.

## Review Focus

- A learner taps Sync with `TODO()` still in `AppFhirSyncTask`. The build log lists it under Still to do and the Output tab shows the exception. Tested in Task 6.
- The VM restarts and HAPI comes back empty. The seeder reloads the three patients without anyone running a command. Tested in Task 4.
- A learner imports `dev.ohs.fhir.model.r4.String` without the alias. `fix-imports` rewrites it and the hints name it. Tested in Task 5.
- The browser database holds data from an earlier step after `step reset`. Clear app data empties it. Tested in Task 6.
- HAPI returns Bundle links. They carry the lab address, not `hapi:8080`. Tested in Task 4.

---

### Task 1 · Scaffold from the SDC lab

**Files.** Create every file in the spec's repository layout except `course-manual.md`, `README.md`, `workspace/solutions/` and `hapi/patients.json`, by copying the SDC file of the same name.

- [ ] Copy the files. Replace `sdc-` names, `kotlin-fhir-data-capture` and `Data Capture` with the engine names from Global Constraints.
- [ ] Verify with `grep -rn -i 'sdc\|data-capture\|datacapture\|webApp' .` that the only hits left are ones later tasks rewrite.

### Task 2 · Starter and step solutions

**Files.** Create `workspace/solutions/{starter,step-4,step-5,step-6,step-7}/` each holding `FhirEngineSetup.kt`, `DownloadWorkManagerImpl.kt`, `AppFhirSyncTask.kt`, `PatientListViewModel.kt`, `PatientListScreen.kt`. `starter/` also holds `Main.kt` (wasmJsMain) and `ForegroundSyncLauncher.kt`. Create `hapi/patients.json` from the pinned `codelabs/data/patients.json`.

**Produces.** numbered import comments of the form `// N Imports for ...` at the end of each file's import group, used by `fix-imports` and the manual.

- [ ] Write `starter/` from the pinned files plus the three starter changes in the spec.
- [ ] Write each step from the code in the pinned `codelabs/README.md`.
- [ ] Verified by the image build in Task 3.

### Task 3 · Workspace image

**Files.** Modify `workspace/Dockerfile`.

- [ ] Point the checkout, starter copy, commit and warm builds at the engine repository, `:shared` task and five files. Build step 7 first, then the starter.
- [ ] Run `docker build -t engine-codelab-workspace:local workspace`. Expected, the build succeeds and the final `git status --porcelain` test passes. If Gradle needs an Android SDK, apply the fallback in the spec.

### Task 4 · Compose, nginx, HAPI, seeder, lab-init, provision

**Files.** Modify `docker-compose.yml`, `nginx/lab-routes.conf`, `lab-init.sh`, `provision-heropa.sh`, `.env.example`.

- [ ] Add `hapi` and `seed` services and the `/fhir/` route. Add the isolation headers to `/app/` and `/preview/`.
- [ ] `lab-init.sh` waits up to 180 seconds for `/fhir/metadata` and prints the FHIR server address.
- [ ] Run `LAB_HOST=localhost LAB_CERT=none LAB_HTTP_PORT=8080 LAB_HTTPS_PORT=8443 ./lab-init.sh`.
- [ ] Verify `curl -s localhost:8080/fhir/Patient` has `"total": 3` and its `link` URLs start with `http://localhost:8080/fhir`.
- [ ] Verify `curl -sI localhost:8080/app/` shows both isolation headers.
- [ ] Verify `docker restart engine-hapi`, then within three minutes the three patients are back.

### Task 5 · Workspace helpers

**Files.** Modify `workspace/bin/{codelab-watch,codelab-hints,fix-imports,step}`. Create `workspace/bin/reset-server`.

- [ ] `codelab-watch` uses the `:shared` task, watches `shared` and `../gradle`, and prints a Still to do list after a good build.
- [ ] `step 4|5|6|7|reset` over the five files.
- [ ] `fix-imports` over the five files, with the `FhirString` rewrite.
- [ ] `codelab-hints` rules for this codelab.
- [ ] `reset-server` posts `/opt/codelab/patients.json` to `http://hapi:8080/fhir/`.
- [ ] Verify in the running lab. `step 5` then `BUILD OK`. Delete an import, see the hint, run `fix-imports`, see `BUILD OK`. Replace the alias import with the bare one, run `fix-imports`, see it restored.

### Task 6 · Pages and editor extension

**Files.** Modify `nginx/html/{index.html,preview/index.html,output/index.html,building.html}`, `workspace/ide/codelab-guide/extension/extension.js`, `workspace/bin/workspace-entrypoint`.

- [ ] Preview gets Clear app data and the `handleMessage` filter. The start page links the FHIR server. The extension opens `FhirEngineSetup.kt`.
- [ ] Verify in a browser against the local lab, following step 3 of How it is checked in the spec, including the `TODO()` case, Clear app data and the Output tab receiving lines.

### Task 7 · Manual and README

**Files.** Create `course-manual.md` and `README.md`.

- [ ] Write both to the shapes in the spec.
- [ ] Verify with one scan that lab-written prose has no em dash, semicolon or colon outside code and URLs.
