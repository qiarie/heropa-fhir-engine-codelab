# Kotlin FHIR Engine codelab on Heropa, design

## Intent

Run the [Manage FHIR Resources codelab](https://ohs-foundation.github.io/ohs-docs/tutorials-and-codelabs/engine/) on a headless Heropa VM, the same way the Data Capture codelab already runs from `/home/kiarie/Desktop/Heropa-SDC-Codelab/` (called the SDC lab below). A learner needs only a browser. This repository is `/home/kiarie/Desktop/Heropa-Engine-Codelab/` and starts empty.

The SDC lab is the model for everything. Its structure, scripts, editor layout, manual style and administrator guide are copied and then changed only where the engine codelab forces a change.

## Goals

* A learner finishes steps 4 to 7 of the codelab in a browser editor and sees the web app sync, update and search patients against a real FHIR server.
* The administrator flow is the same as the SDC lab, which is `provision-heropa.sh`, then `lab-init.sh`, then `lab-init.sh --clean` before saving the template.
* The learner manual keeps all of the published text and sets apart what only applies to Android Studio or to a learner's own computer.

## Non-goals

* Android, desktop and iOS targets. Only the web target runs.
* Changing the SDC lab or sharing code between the two repositories.
* Keycloak, the Info Gateway, Postgres, Superset or the pipelines from the OHS Player lab. Only HAPI FHIR is taken from there.
* Showing the lab inside Heropa interface tabs. Learners open it in their own browser tabs, as in the SDC lab.

## Anti-goals

* A learner having to run Docker commands, install anything or open browser developer tools.
* A sync that fails with nothing on screen to say why.
* A lab that only works when the learner's browser can reach `localhost` on the VM.

## Constraints

* The codelab is pinned to commit `697412d04157980fc24eb3fbb2e8e5c479b0f0ee` of `https://github.com/ohs-foundation/kotlin-fhir-engine.git`. The manual text comes from `codelabs/README.md` at that commit.
* The web target lives in the `:shared` module. The build task is `:shared:wasmJsBrowserDevelopmentExecutableDistribution` and the output folder is `shared/build/dist/wasmJs/developmentExecutable/`. The builder confirms both on the first build.
* The app stores its database in the browser through SQLite on OPFS. That needs a cross-origin isolated page, so the app and every page that frames it must be served with `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`.
* The published web entry point calls `http://localhost:8080/fhir/`, which in a learner's browser is their own computer.
* Documentation prose in this repository carries no em dashes, semicolons or colons in displayed text. Text taken from the published codelab keeps its own punctuation.
* The VM is Ubuntu 24.04 with 4 vCPU and 16 GB, the same as the SDC lab.

## Approaches

Three ways of building the lab were considered.

| Approach | Trade off |
|---|---|
| Copy the SDC lab into this repository and adapt it | Some duplicated scripts across two repositories. Nothing in the working SDC lab is touched, and every lesson already learned there carries over. |
| Pull the common parts into one shared base that both labs use | Less duplication, but it reworks a lab that already works and was not asked for. |
| Serve the app from the webpack dev server the codelab uses, proxied by nginx | Closer to the published command and it sets the isolation headers by itself. It needs a web socket through nginx, misses Gradle file edits and drops the watcher, status file and preview flow the SDC lab relies on. |

The first was picked, because the request is to follow the SDC lab.

Three ways of reaching the FHIR server were considered.

| Approach | Trade off |
|---|---|
| nginx serves HAPI at `/fhir/` on the lab address | Same origin as the app, so no CORS and no second certificate. The server is open to anyone who knows the address. |
| A second sslip.io name for the server | Needs CORS, a second certificate and cross-origin resource headers for the isolated app. |
| The gateway and Keycloak from the OHS Player lab | Far more than the codelab needs. |

The first was picked. The user accepted an open server, since it holds only three made up patients.

## Decided by the user

* The FHIR server is open, with no password, at `<lab address>/fhir/`.
* The lab address is worked out as in the OHS Player lab. The script reads the VM's public IP from the AWS instance metadata service and uses `https://<a-b-c-d>.sslip.io` with a Let's Encrypt certificate. The SDC `lab-init.sh` already does exactly this, so it is reused.
* Only HAPI FHIR is taken from the OHS Player stack.
* Everything else follows the SDC lab.

The rest of this document is the author's proposal.

## Containers

The compose project is named `engine-codelab`.

| Service | Container | What it does |
|---|---|---|
| `workspace` | `engine-workspace` | JDK 21, the pinned checkout, a warm Gradle cache, code-server and the build watcher. Image `engine-codelab-workspace:local`. |
| `hapi` | `engine-hapi` | `hapiproject/hapi:v8.12.0-2`, the version the codelab's own compose file uses, with its built in H2 database and no Postgres. Not published on the VM. |
| `seed` | `engine-seed` | `curlimages/curl:8.11.1`. Loads `patients.json` whenever the server is up and the test patients are missing, then keeps checking. A one shot seeder would not run again after an idle stop and restart of the VM. |
| `nginx` | `engine-nginx` | The only published service. Terminates HTTPS and gives each part a path. |

HAPI settings, passed as environment properties.

* `hapi.fhir.use_apache_address_strategy=true` and `hapi.fhir.use_apache_address_strategy_https=true`, taken from the OHS Player lab, so links inside returned Bundles carry the lab address. The engine follows the `next` link when a download has more pages.
* A heap limit of 1 GB through `JAVA_TOOL_OPTIONS`.
* `restart: unless-stopped`.

The server keeps whatever database the image uses by default and gets no volume. This is the author's call. If that database does not survive a restart of the VM, the seeder puts the three patients back in their first state, while the learner's browser still holds its own copy. The manual's Troubleshooting section covers this case. It tells the learner to click **Clear app data** and then **Sync** after the VM was stopped. Keeping the data would need a volume the image's unprivileged user can write to, which is more than three test patients are worth.

The HAPI image has no shell, so there is no container health check. `lab-init.sh` and the seeder wait on `/fhir/metadata` instead.

A copy of the codelab's `data/patients.json` is kept in this repository at `hapi/patients.json` for the seeder, and is checked against the pinned commit when the pin changes.

## Paths

| Path | What it serves |
|---|---|
| `/` | Start page with links to the Editor, the App and the FHIR server |
| `/ide/` | The editor |
| `/preview/` | The app with the status bar, refresh button and output strip. Sent with the two isolation headers. |
| `/app/` | The app alone, from `kotlin-fhir-engine/codelabs/shared/build/dist/wasmJs/developmentExecutable/` in the learner's volume. Sent with the two isolation headers. |
| `/fhir/` | Proxied to `hapi:8080` with the path unchanged, plus `X-Forwarded-Proto`, `X-Forwarded-Host` and `X-Forwarded-Port`. |
| `/buildlog/`, `/output/`, `/app-status.json`, `/build.log` | As in the SDC lab |

## Changes to the starter code

The image build makes three changes to the checkout and commits them, the way the SDC lab commits its import markers. `step reset` returns to that commit. The README lists all three as differences from the published starter.

1. `shared/src/wasmJsMain/kotlin/dev/ohs/fhir/codelab/Main.kt` builds the base URL from the page's own address, which is `window.location.origin` plus `/fhir/`. Learners never edit this file.
2. Each of the five files a learner edits gets numbered import comments under its import group, one for each step that adds imports to that file, such as `// 5.2 Imports for the sync task`.
3. `ForegroundSyncLauncher.kt` prints the exception it catches before it reports the sync as failed. The published file swallows it, so a sync that fails before any HTTP request would leave nothing in the Output tab. Learners never edit this file. This is the author's call.

## Sync failures that compile

Some mistakes build cleanly and only fail when the learner taps **Sync**. The main one is a `TODO()` left in `AppFhirSyncTask`. Build hints cannot catch these, because hints only run on a failed build. Two things cover them.

* After each good build the watcher scans the five files and prints a short **Still to do** list in the build log, naming any numbered codelab comment or `TODO()` that is still there.
* The printed exception from the change above appears in the Output tab.

## Helper commands in the workspace

| Command | What it does |
|---|---|
| `step 4`, `step 5`, `step 6`, `step 7` | Replaces the five files with their state at the end of that step. Backs up first. |
| `step reset` | Returns the five files to the starter. Tells the learner to click **Clear app data** in the App tab as well. |
| `fix-imports` | Adds missing imports to all five files under the right numbered comment. Replaces a bare `import dev.ohs.fhir.model.r4.String` with the `as FhirString` form. |
| `reset-server` | Loads `patients.json` into HAPI again over the Docker network, which puts the three patients back to their first state. It stands in for the codelab's `docker compose down` and `up`. |
| `build-log` | As in the SDC lab |

`workspace/solutions/` holds `starter/`, `step-4/`, `step-5/`, `step-6/` and `step-7/`, each with the five files. The step solutions are written from the code in the pinned README.

`codelab-hints` gets rules for this codelab. The main ones are each missing import by name, the `FhirString` alias trap and step order mistakes such as calling `searchByCity` before step 6.1.

## The editor

The layout, extension and status bar are the SDC ones. `FhirEngineSetup.kt` is the file opened at start, since step 4 edits it first. The app name shown by code-server is `FHIR Engine codelab`.

## The App tab

The SDC preview page, with three changes.

* A **Clear app data** button. It unloads the app, deletes the OPFS files for the lab address and reloads. The browser database outlives `step reset` and a VM reset, so a learner needs a way to empty it.
* The output filter drops the SQLite worker's `handleMessage` lines, which arrive once per query.
* The empty text of the output strip says that the engine's HTTP log appears there after a sync.

The Output tab stays in the editor. This codelab has no Logcat steps, but the engine logs each HTTP request and response to the browser console when `debug` is true, and a failed sync shows nothing in the app. The manual points learners at the Output tab when a sync does not finish.

The Output tab learns of new lines through browser storage events sent from the App tab. The App tab is now cross-origin isolated, so the builder checks that those events still arrive, and falls back to polling the storage every second if they do not.

## lab-init.sh and provision-heropa.sh

Both are the SDC scripts with the names changed. `lab-init.sh` also waits for `/fhir/metadata`, which can take two minutes on a cold start, and prints a fourth line with the FHIR server address. `--reset` and `--clean` remove the HAPI container along with the learner volume, so the server starts again from the seed data. `provision-heropa.sh` also pulls the HAPI and curl images.

Local testing works as in the SDC lab, with `LAB_HOST=localhost LAB_CERT=none LAB_HTTP_PORT=8080`. HAPI is not published on the host, so its port does not clash.

## The learner manual

`course-manual.md` follows the SDC manual's shape. Lab instructions are the main text, and passages that only fit Android Studio or a learner's own computer are quoted blocks that start with **Android Studio only.**

| Exercise | Heading |
|---|---|
| 1 | Before you begin |
| 2 | Get set up, which covers starting the lab, the tour of the editor, checking the FHIR server at `/fhir/Patient` and what the editor does not do |
| 3 | Set up the project |
| 4 | Create the FHIR Engine instance |
| 5 | Sync data with the FHIR server |
| 6 | Modify and upload patient data |
| 7 | Search for patients by name |
| 8 | Congratulations |
| 9 | Troubleshooting |

Passages set apart as Android Studio only are the list of tools, the download, starting the server with Docker Compose, the import into Android Studio, the Gradle sync, running on a device, the other platforms, the import prompts, the `10.0.2.2` address with `FhirApplication`, and the WorkManager launcher. The manual says that on the web the sync runs in the foreground.

The lab text adds where each file is, where each import goes, the lab form of every `localhost` address, the **Clear app data** button, `reset-server`, and a note that the Editor and App tabs must be in the same browser and not in a private window. The five published screenshots show the Android app and are linked from GitHub at the pinned commit, with a line saying the web app looks slightly different.

## README.md

The administrator guide follows the SDC `README.md` section by section, with the engine facts in place of the SDC ones. It adds the FHIR server, the open server note, the isolation headers and the browser database.

## Repository layout

```
README.md  course-manual.md  docker-compose.yml  lab-init.sh  provision-heropa.sh
.env.example  .gitignore  .dockerignore
hapi/patients.json
nginx/lab-http.conf.template  lab-https.conf.template  lab-routes.conf
nginx/html/index.html  building.html  preview/  buildlog/  output/
workspace/Dockerfile
workspace/bin/build-log  codelab-hints  codelab-watch  fix-imports  step  reset-server  workspace-entrypoint
workspace/ide/bashrc  settings.json  codelab-guide/
workspace/solutions/starter  step-4  step-5  step-6  step-7
```

## Left to the builder

* The exact wording of the import comments and which sub-step each belongs to.
* The exact hint rules, found by breaking each step on purpose and reading the compiler output.
* Whether Gradle configures the Android modules without an Android SDK here, as it does in the SDC lab. If it does not, the image build removes `:androidApp` from the committed `settings.gradle.kts` or supplies what is missing, and the README records it.
* Memory use with HAPI running, measured during a build.

## How it is checked

1. The image builds, which compiles step 7 and then the starter.
2. Each of `step 4` to `step 7` builds in a local lab.
3. In a browser against the local lab, the starter shows Hello World, step 4 shows the empty list, step 5 syncs three patients, step 6 swaps the two cities and `/fhir/Patient` shows the swap, and step 7 filters by name.
4. `reset-server`, **Clear app data**, `fix-imports` and `step reset` each do what the manual says.
5. Every documentation page is scanned for the banned punctuation in one pass.

A run on a real Heropa VM with Let's Encrypt is the administrator's walk through in the README and is not part of this build.
