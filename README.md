# Kotlin FHIR Engine codelab on Heropa

This repository runs the [Kotlin FHIR Engine codelab](https://ohs-foundation.github.io/ohs-docs/tutorials-and-codelabs/engine/) on a headless Heropa VM. Learners need only a browser. They do not install Android Studio, an emulator, a JDK, Docker or anything else.

This guide is for the Heropa administrator who builds and maintains the course. Learners follow `course-manual.md`.

## How it works

The codelab is a Kotlin Multiplatform app that syncs patients with a FHIR server. Everything a learner writes goes into shared code, and the starter project already has a web target. The lab builds that web target on the VM and serves it to the learner's browser, so the VM needs no screen. The lab also runs the FHIR server the app syncs with.

Each learner gets one VM running four containers.

| Container | What it does |
|---|---|
| `engine-workspace` | Holds the JDK, the codelab checkout, a warm Gradle cache and code-server, which is VS Code in a browser. A watcher rebuilds the app after every save. |
| `engine-hapi` | The HAPI FHIR server, with the database built into its image. It is not published on the VM. |
| `engine-seed` | Loads the three test patients whenever the server is up and does not have them. |
| `engine-nginx` | The only published service. It terminates HTTPS and gives each part of the lab a path. |

| Path | What the learner sees |
|---|---|
| `/` | A start page with links to the three below |
| `/ide/` | The editor. It shows the code, the build log and the manual side by side. |
| `/preview/` | The app the learner is building, with a status bar, a refresh button, a **Clear app data** button and an output strip around it. This is the learner's App tab. |
| `/fhir/` | The FHIR server. Learners open `/fhir/Patient` to check its data. |
| `/app/` | The app with nothing around it |
| `/buildlog/` | A page that follows the build log. The editor embeds this page. |
| `/output/` | A page that shows what the app printed. The editor embeds this page too. |

The learner loop is short. They save a file and wait for `BUILD OK` in the build log under the code. The App tab then reloads by itself.

Learners work in two browser tabs, the Editor and the App. The editor opens in a fixed layout, so nobody has to arrange panes.

| Area | Where | What it shows |
|---|---|---|
| Code | Top centre, about three fifths of the width | `FhirEngineSetup.kt`, already open |
| Build log | Under the code | Each build, its errors, plain advice for the common ones and the steps still to do |
| Output | A tab next to the build log | What the app prints, which is each request to the FHIR server and the reason when a sync fails |
| Terminal | A tab next to the output | An ordinary shell |
| Guide | Right, at full height | `course-manual.md`, rendered |

### The lab address

`lab-init.sh` works out the address the same way the OHS Player lab does. It reads the VM's public IP from the AWS instance metadata service and uses `https://<a-b-c-d>.sslip.io`, a name that the public sslip.io DNS answers with that IP. It then gets a Let's Encrypt certificate for that name through the certbot image. Every part of the lab, the FHIR server included, is a path on that one address.

### The FHIR server

Only HAPI FHIR is taken from the OHS Player stack. There is no Keycloak, gateway, Postgres or pipeline.

| Fact | Detail |
|---|---|
| Image | `hapiproject/hapi:v8.12.0-2`, the version the codelab's own compose file uses |
| Address | `/fhir/` on the lab address. The app and the server share one address, so the browser needs no cross site rules. |
| Access | Open, with no password. Anyone who knows a VM's address can read and write to it while the lab runs. It holds three made up patients and must never hold real data. |
| Links | HAPI is told to build the links inside a Bundle from the forwarded headers nginx sends, so they carry the lab address. |
| Memory | The heap is limited to 1 GB. |
| Data | Kept in memory, with no volume. See the next paragraph. |

The image's default database lives in memory, so the server starts empty every time its container starts, which includes every restart of the VM. That is why the seeder keeps running. It checks every 20 seconds and loads `hapi/patients.json` whenever the first test patient is missing. A learner who comes back after an idle stop therefore finds the three patients in their first state, while their browser may still hold changed copies. The manual's Troubleshooting table tells them to click **Clear app data** and then **Sync**.

`hapi/patients.json` is a copy of `codelabs/data/patients.json` from the pinned commit.

### The database in the browser

The app keeps its data in SQLite inside the learner's browser, in the storage the browser calls OPFS. Three things follow from that.

| Consequence | What the lab does |
|---|---|
| The browser only allows it on a page that is isolated from other sites | nginx sends `Cross-Origin-Opener-Policy` and `Cross-Origin-Embedder-Policy` headers on `/app/`, `/preview/` and the waiting page |
| Nothing on the VM can reach or reset it | The App tab has a **Clear app data** button, which unloads the app, deletes the stored files and reloads |
| Private windows may refuse the storage | The manual asks for an ordinary browser window |

### Why the web target

| Target | Why it is or is not used |
|---|---|
| Web with Wasm | Used. It runs in the learner's own browser, so the VM needs no display. |
| Android | Not used. It needs an emulator with nested virtualisation and a screen to show it on. |
| Desktop on the JVM | Not used. It opens a window, and the VM has no desktop. |
| iOS | Not used. It needs a Mac. |

Building the web target needs no Android SDK. Gradle configures the Android modules without one and never compiles them.

### What differs from the published codelab

| The codelab says | In this lab |
|---|---|
| Download the code | Already in the workspace |
| Run `docker compose up -d` to start a FHIR server | Already running |
| Open `http://localhost:8080/fhir/Patient` | Open the lab address followed by `/fhir/Patient` |
| Run `docker compose down` and `up` to reset the server | Type `reset-server` in the editor terminal |
| Import the app into Android Studio | Open the Editor tab |
| Sync Project with Gradle Files | Nothing. Every build reads the Gradle files. |
| Click **Run** | Save the file and wait for `BUILD OK`. The App tab reloads by itself. |
| The HTTP log shows in Logcat or the browser console | Read the Output tab in the editor, next to the build log |
| Android Studio prompts you to add an import | Type or paste the import. The manual lists each one, and `fix-imports` adds them. |
| On Android the sync runs in the background through WorkManager | On the web it runs in the foreground, while the App tab is open |

The image build changes three things in the starter code and commits them, so `step reset` returns to that state.

| Change | File | Why |
|---|---|---|
| The FHIR server address is read from the page's own address | `shared/src/wasmJsMain/kotlin/dev/ohs/fhir/codelab/Main.kt` | The published file says `http://localhost:8080/fhir/`, which in a learner's browser is their own computer |
| Numbered import comments, such as `// 5.2 Imports for the sync task` | `FhirEngineSetup.kt`, `DownloadWorkManagerImpl.kt`, `AppFhirSyncTask.kt` and `PatientListViewModel.kt` | The published starter marks each place for code with a numbered comment but has none for imports |
| The exception a failed sync throws is printed, as a line that starts with `Sync failed` | `ForegroundSyncLauncher.kt` | The published file swallows it, and the app shows nothing when a sync fails |

The editor colours Kotlin but has no code completion, no import prompts and no error underlining. Five things stand in for them.

| Stand-in | What it does |
|---|---|
| Build hints | After a failed build, the panel prints a **What to do** list that names the missing or wrong import in plain words. `workspace/bin/codelab-hints` holds the rules. |
| Still to do | After a good build, the panel lists every numbered codelab comment and every `TODO()` still in the five files. A `TODO()` left in `AppFhirSyncTask.kt` builds without error and only fails when the learner clicks **Sync**, so the build alone cannot report it. The Output tab then shows `NotImplementedError`, and the preview page adds a line saying which step to finish. |
| `fix-imports` | Adds the imports the code in the five files needs and repairs the `String` import. A **Fix imports** button in the status bar runs it. |
| `step N` | Replaces the five files with a working version of step N, from 4 to 7. |
| `reset-server` | Loads the three test patients into the FHIR server again. |

The most common mistake is importing `dev.ohs.fhir.model.r4.String` in step 6 without `as FhirString`. The FHIR type and Kotlin's own `String` share that name. The manual has a part on this, named "What this editor does not do for you".

## Repository layout

| Path | Purpose |
|---|---|
| `provision-heropa.sh` | Installs Docker on the VM, builds the workspace image and pulls the other images |
| `lab-init.sh` | Works out the lab address, gets the certificate, creates the editor password and starts the lab |
| `docker-compose.yml` | The four containers and the volume that holds the learner's work |
| `hapi/patients.json` | The three test patients |
| `workspace/Dockerfile` | The workspace image, pinned to one commit of the codelab |
| `workspace/bin/` | The build watcher, the build hints, the `fix-imports`, `step` and `reset-server` helpers and the container entry point |
| `workspace/solutions/` | The five codelab files as they stand at the end of steps 4 to 7, and the lab's version of the starter files |
| `workspace/ide/` | Editor settings and the small extension that lays out the code, build log and manual |
| `nginx/` | The path routes and the static pages, which are the start page, the app preview, the build log, the output and the waiting page |
| `course-manual.md` | The learner manual, shaped as Heropa Sections and Exercises |
| `docs/superpowers/` | The design and the plan this lab was built from |

## Step 1 · Get a VM image

Ask the Heropa team for an Ubuntu 24.04 LTS server image in your region, or import your own. Use these settings.

| Setting | Value |
|---|---|
| OS type | Linux |
| Connection type | The terminal connection Heropa offers for Linux servers |
| Instance type | 4 vCPU and 16 GB memory, for example `m5.xlarge` |
| Storage | 30 GB |

In a local test the workspace container used about 5.6 GB after building every step, and the FHIR server about 1.3 GB. 16 GB leaves room for both and for the browser sessions the editor serves. 8 GB has not been tested.

## Step 2 · Create the template

1. In the Heropa portal open **Templates** and click **Add**.
2. Give it a title such as `FHIR Engine codelab`, pick the same region as the image and click **Create**.
3. On the **Details** tab click **Add VM** and add the image from Step 1.
4. Open the VM's row action menu and choose **Edit network**.
   1. Tick **Allocate a permanent public IP address**. The lab address is made from this IP, so it must survive an idle stop.
   2. Add inbound rules for TCP 80 and TCP 443 from `0.0.0.0/0`. Let's Encrypt checks over port 80 from addresses it does not publish, so that rule cannot be narrowed.

   Leave outbound traffic allowed. The first build needs it for the images, and anything a learner adds beyond the codelab is downloaded.

Learners open the lab in tabs of their own browser, not in Heropa interface tabs. A Heropa Website tab takes one fixed URL, and each learner's address is different.

## Step 3 · Prepare the VM

Launch an environment from the template and open the VM's terminal.

1. Put this repository on the VM and run the provisioning script.

   ```bash
   git clone <this repository> ~/engine-codelab
   cd ~/engine-codelab
   sudo ./provision-heropa.sh
   ```

   It installs Docker, pulls nginx, certbot, HAPI FHIR and curl, and builds the workspace image. The build clones the codelab, downloads every dependency and compiles the app twice, so allow around fifteen minutes.

2. Pick up the new group, then start the lab once.

   ```bash
   newgrp docker
   ./lab-init.sh
   ```

   It prints the Editor address, the editor password, the App address and the FHIR server address.

3. Open the Editor and App addresses in your own browser and walk the learner manual from start to finish.

4. Remove everything that belongs to this one VM, keeping the images.

   ```bash
   ./lab-init.sh --clean
   docker image ls
   ```

   `--clean` stops the lab, deletes the volume with your test edits and the FHIR server with its data, and removes `.env` and the certificate. Without it every learner would share one editor password and start from your code. It keeps the `letsencrypt` folder, which is harmless in the template because each learner's VM has a different address and asks for its own certificate.

5. Save the environment as a new template and use that saved template in the course.

### What the learner's first run costs

`./lab-init.sh` on a fresh VM takes two to three minutes. Most of it is the FHIR server starting, and the rest is the certificate request and Docker copying the checkout and the Gradle cache into the learner's volume. The App tab shows the starter app as soon as the first build finishes, which is quick because the image already built it.

## Step 4 · Create the policy

| Setting | Value |
|---|---|
| Access period | 3 hours |
| Limit Active time | On, 2 hours |
| Idle action | Stop the VMs after 30 minutes idle |

A stopped VM keeps its disk and its permanent public IP. All four containers restart with the VM, and the learner's code is still in the volume. Running `./lab-init.sh` again prints the same addresses and password. The FHIR server needs a minute or two after a restart, and it comes back with the three test patients in their first state.

## Step 5 · Add the content

`course-manual.md` is written for the Heropa lab and its web editor. The lab instructions are the main text. Anyone who wants to use Android Studio is sent to the published codelab on the website instead.

It is built on the published codelab and keeps all of its text. The passages that only make sense in Android Studio, or on a learner's own computer, are kept but set apart.

| Kind of text | How to spot it |
|---|---|
| Lab instructions and the codelab's own explanations and code | Plain text |
| A passage that applies only to Android Studio or to a learner's own computer | A quoted block that starts with **Android Studio only.** and tells the learner to skip it |

The blocks marked that way are the example in the introduction, the list of tools, the download, starting the server with Docker Compose, the import into Android Studio, the Gradle sync, running on a device, the other platforms, the three import prompts, the Android call with `10.0.2.2`, the WorkManager launcher, the `localhost` check in step 6 and the four pictures of the Android app.

The lab text adds these things the original leaves to Android Studio or to a local setup.

* The exact file to open and how to reach it in the Explorer, for learners who have never seen a Gradle project
* Where each import line goes, since the web editor does not offer imports
* The lab form of each `localhost` address
* What to do when a sync fails, since the app itself shows nothing
* The **Clear app data** button and the `reset-server` command

The manual maps onto Heropa content as one Section, with one Exercise for each second level heading.

| Exercise | Heading |
|---|---|
| 1 | Before you begin |
| 2 | Get the code and start a FHIR server, which includes starting the lab, the tour of the editor and checking the server |
| 3 | Set up the project, which includes how to run the app and what the editor does not do |
| 4 | Create the FHIR Engine instance |
| 5 | Sync data with the FHIR server |
| 6 | Modify and upload patient data |
| 7 | Search for patients by name |
| 8 | Congratulations |
| 9 | Troubleshooting |

Load it as Custom content by pasting each exercise into the rich text editor, or publish it through GitBook and add it as External content. The five pictures load from GitHub at the pinned commit, so they need no upload.

The text taken from the published codelab keeps its own punctuation and line breaks. Only the text written for the lab follows this repository's prose rule.

## Step 6 · Create and publish the course

Create a course that ties together the template saved in Step 3, the policy from Step 4 and the content from Step 5, then publish it.

## The layout inside the editor

VS Code has no setting that opens files or pages when it starts, so a small extension in `workspace/ide/codelab-guide/` builds the layout. It is packaged into the image at build time and needs no marketplace.

| Area | How it is made |
|---|---|
| Guide | The Markdown preview that ships with the editor, opened on `course-manual.md` |
| Build log | A web view that frames `/buildlog/` |
| Output | A web view that frames `/output/` |
| Terminal | An ordinary terminal, placed in a tab next to the output |

The status bar has five buttons. **Open app** opens `/preview/` in a new browser tab. **Guide**, **Build log** and **Output** reopen an area that was closed. **Fix imports** runs the `fix-imports` helper. The layout comes back after a page reload.

The app runs in one browser tab and the Output tab sits in another, so the output has to travel between them. No server is involved. The preview page listens to the app's console and saves each printed line in the browser's local storage for the lab address. The `/output/` page reads that storage, checks it again every second and a half, and asks the editor to bring the Output tab to the front when something new arrives. This works because both pages come from the same address, and it means the two tabs must be open in the same browser. The preview page drops the line the database worker prints for every query, which would bury everything else.

To change the default sizes, edit `LAYOUT` near the top of `extension/extension.js` and rebuild the image.

The preview page knows when to reload because the build watcher writes its state to a small file, served at `/app-status.json`. The page polls it every second and a half. It can show what the app prints because it frames the app from the same address, which lets it listen to the app's console.

The app, the FHIR server, the build log and the status file are served without a password. Only the editor asks for one. The build log holds compiler output and nothing secret.

The manual is mounted into the workspace container, not copied into the image. After editing it on the VM, run `docker compose restart workspace` and reload the Editor tab.

The same text can still be loaded as Heropa content. Learners then have it in both places.

## Updating the codelab version

The workspace image is pinned to one commit of the codelab through `CODELAB_REF` in `workspace/Dockerfile`. The files in `workspace/solutions/` were written against that commit.

To move to a newer commit, do these in order.

1. Change `CODELAB_REF` in `workspace/Dockerfile`.
2. Update the files in `workspace/solutions/` to match the new codelab text. `starter/` holds the published starter files with the three lab changes described above. The image build copies them over the checkout and commits them.
3. Copy the new `codelabs/data/patients.json` to `hapi/patients.json`, and match the HAPI image version in `docker-compose.yml` and `provision-heropa.sh` to the codelab's own compose file.
4. Carry the changes in the new `codelabs/README.md` over to `course-manual.md`, keeping the lab text and the **Android Studio only** blocks. Update the commit in the picture addresses and the repository links.
5. Check the line numbers the manual quotes, and the names and imports in `fix-imports` and `codelab-hints`.
6. Rebuild the image, walk the manual again and save a new template.

## Testing without Heropa

The lab runs on any machine with Docker. This starts it on `http://localhost:8080` over plain HTTP.

```bash
docker build -t engine-codelab-workspace:local workspace
LAB_HOST=localhost LAB_CERT=none LAB_HTTP_PORT=8080 LAB_HTTPS_PORT=8443 ./lab-init.sh
```

Pick other ports if those two are taken. The FHIR server is not published on the machine, so it never clashes with a port.

Browsers treat `http://localhost` as a secure page, so the editor and the browser database work in full without a certificate. Do not use `LAB_CERT=self-signed` for this. The editor's web views, the guide pane among them, need a service worker, and browsers refuse to register one on a certificate they do not trust, even after you accept the warning. On Heropa the Let's Encrypt certificate is trusted, so this does not arise.

## Troubleshooting

| Symptom | Fix |
|---|---|
| The guide pane shows `Could not register service worker` | The page is on a certificate the browser does not trust. On Heropa check that the lab got its Let's Encrypt certificate. On your own machine use `LAB_CERT=none`. |
| `certbot failed` | Check the inbound rules for TCP 80 and 443, and that the VM has a public IP. |
| The App tab stays on the waiting page | Read the build with `docker exec engine-workspace build-log`. |
| `/fhir/Patient` says the FHIR server is still starting | It takes a minute or two. If it lasts longer, read `docker compose logs hapi`. |
| `/fhir/Patient` shows a `total` of 0 | Read `docker compose logs seed`. To load the patients by hand, run `docker exec engine-workspace reset-server`. |
| The app loads but never shows its first screen | The isolation headers are missing. Check them with `curl -sI <lab address>/app/`. |
| A build stops with `returns 127` | `libatomic1` is missing from the image. The Dockerfile installs it, so the image was changed. |
| The editor asks for a password nobody has | Run `./lab-init.sh` again. It prints the password. |
| A learner broke their code beyond repair | In the editor terminal run `step reset`, or on the VM run `./lab-init.sh --reset`. |
| Builds are killed or the VM swaps | The VM has less than 16 GB. Use a larger instance type. |
