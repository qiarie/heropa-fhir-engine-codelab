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
| `engine-seed` | Loads the test data whenever the server is up and does not have it. That is the three test patients, and the PlanDefinition with its two ActivityDefinitions. |
| `engine-nginx` | The only published service. It terminates HTTPS and gives each part of the lab a path. |

| Path | What the learner sees |
|---|---|
| `/` | A start page with links to the three below |
| `/ide/` | The editor. It shows the code, the build log and the manual side by side. |
| `/preview/` | The app the learner is building, with a status bar, a refresh button, a **Clear app data** button and an output strip around it. This is the learner's App preview tab. |
| `/fhir/` | The FHIR server. Learners open `/fhir/Patient` to check its data. |
| `/app/` | The app with nothing around it |
| `/buildlog/` | A page that follows the build log. The editor embeds this page. |
| `/output/` | A page that shows what the app printed. The editor embeds this page too. |
| `/build.log` | The build log as plain text, which the build log page reads |
| `/qr/` | The QR picture the start page shows |

The learner loop is short. They save a file and wait for `BUILD OK` in the build log under the code. The App preview tab then reloads automatically. Builds need no command, because a watcher in the workspace starts one after every save. A learner can also start one by hand with the **Build now** button or the `build` command.

Learners work in two browser tabs, the Editor and the App preview. The editor opens in a fixed layout, so nobody has to arrange panes.

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
| Access | Open, with no password. Anyone who knows a VM's address can read and write to it while the lab runs. It holds three made up patients, plus whatever learners register, and must never hold real data. |
| Links | HAPI is told to build the links inside a Bundle from the forwarded headers nginx sends, so they carry the lab address. |
| Memory | The heap is limited to 1 GB. |
| Data | Kept in memory, with no volume. See the next paragraph. |
| Search cache | Off, as in the codelab's own compose file. With the default the server reuses a search answer for a minute, so a sync straight after the test data loads could miss it. |
| Expunge and multiple delete | Both on, so `reset-server` can empty the database. The server refuses that request unless both are. |

The image's default database lives in memory, so the server starts empty every time its container starts, which includes every restart of the VM. That is why the seeder keeps running. It checks every 20 seconds and loads every file in `hapi/` whenever the first test patient or the PlanDefinition is missing. A learner who comes back after an idle stop therefore finds the three patients in their first state, while their browser may still hold changed copies. The manual's Troubleshooting table tells them to click **Clear app data** and then **Sync**.

`hapi/patients.json` and `hapi/registration-plan.json` are copies of the two files in `codelabs/data/` at the pinned commit. The second holds the PlanDefinition and the two ActivityDefinitions that step 10 downloads.

### The database in the browser

The app keeps its data in SQLite inside the learner's browser, in the storage the browser calls OPFS. Three things follow from that.

| Consequence | What the lab does |
|---|---|
| The browser only allows it on a page that is isolated from other sites | nginx sends `Cross-Origin-Opener-Policy` and `Cross-Origin-Embedder-Policy` headers on `/app/`, `/preview/` and the waiting page |
| Nothing on the VM can reach or reset it | The App preview tab has a **Clear app data** button, which unloads the app, deletes the stored files and reloads |
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
| Click **Run** | Save the file and wait for `BUILD OK`. The App preview tab reloads automatically. |
| The HTTP log shows in Logcat or the browser console | Read the Output tab in the editor, next to the build log |
| Android Studio prompts you to add an import | Type or paste the import. The manual lists each one, and `fix-imports` adds them. |
| On Android the sync runs in the background through WorkManager | On the web it runs in the foreground, while the App preview tab is open |

The image build changes three things in the starter code and commits them, so `step reset` returns to that state.

| Change | File | Why |
|---|---|---|
| The FHIR server address is read from the page's own address | `shared/src/wasmJsMain/kotlin/dev/ohs/fhir/codelab/Main.kt` | The published file says `http://localhost:8080/fhir/`, which in a learner's browser is their own computer |
| Numbered import comments, such as `// 5.2 Imports for the sync task` | `FhirEngineSetup.kt`, `DownloadWorkManagerImpl.kt`, `AppFhirSyncTask.kt`, `PatientListViewModel.kt`, `RegistrationScreen.kt` and `EngineWorkflowRepository.kt` | The published starter marks each place for code with a numbered comment but has none for imports |
| The exception a failed sync throws is printed, as a line that starts with `Sync failed` | `ForegroundSyncLauncher.kt` | The published file drops it, and the app shows only `Sync Failed` with no reason |

The same commit adds one build setting, `kotlin.incremental.wasm=true`, to `codelabs/gradle.properties`. A build after a small edit then rebuilds only what the edit changed, which on a test machine with 16 cores took about 13 seconds where it took about 38 before. Kotlin 2.3.21 marks the setting as experimental. If a build ever leaves a stale app in the App preview tab, remove that line from the image build in `workspace/Dockerfile` and build the image again.

The editor colours Kotlin but has no code completion, no import prompts and no error underlining. Seven things make up for them.

| Stand-in | What it does |
|---|---|
| Build hints | After a failed build, the Build log prints a **What to do** list that names the missing or wrong import in plain words. `workspace/bin/codelab-hints` holds the rules. |
| `build` | Starts a build without a save. The build watcher runs it, so it shows in the build log like any other. A **Build now** button in the status bar saves every open file and then runs it. |
| Still to do | After a good build, the Build log lists every numbered codelab comment and every `TODO()` still in the seven files. A `TODO()` left in `AppFhirSyncTask.kt` builds without error and only fails when the learner clicks **Sync**, so the build alone cannot report it. The Output tab then shows `NotImplementedError`, and the preview page adds a line saying which step to finish. |
| `fix-imports` | Adds the imports the code in the seven files needs and repairs the `String` and `Questionnaire` imports. A **Fix imports** button in the status bar runs it. |
| `step N` | Replaces the seven files with a working version of step N, from 4 to 11. |
| `step reset` | Puts the seven files back to the starter code. |
| `reset-server` | Empties the FHIR server and loads the test data again. |

The most common mistake is importing `dev.ohs.fhir.model.r4.String` in step 6 without `as FhirString`. The FHIR type and Kotlin's own `String` share that name. The manual has a part on this, named "What this editor does not do for you".

## Repository layout

| Path | Purpose |
|---|---|
| `provision-heropa.sh` | Installs Docker on the VM, builds the workspace image and pulls the other images |
| `lab-init.sh` | Works out the lab address, gets the certificate, creates the editor password and starts the lab |
| `.env.example` | Every setting with its options and default. `lab-init.sh` copies its values into `.env` on the first run. |
| `docker-compose.yml` | The four containers and the volume that holds the learner's work |
| `hapi/patients.json` | The three test patients |
| `hapi/registration-plan.json` | The PlanDefinition and the two ActivityDefinitions for steps 10 and 11 |
| `workspace/Dockerfile` | The workspace image, pinned to one commit of the codelab |
| `workspace/bin/` | The build watcher, the build hints, the `build`, `build-log`, `fix-imports`, `step` and `reset-server` helpers and the container entry point |
| `workspace/solutions/` | The seven codelab files as they stand at the end of steps 4 to 11, and the lab's version of the starter files |
| `workspace/ide/` | Editor settings, the shell settings for the Terminal and the small extension that lays out the code, build log and manual |
| `nginx/` | The HTTPS and plain HTTP fronts, the path routes and the static pages, which are the start page, the app preview, the build log, the output and the waiting page |
| `course-manual.md` | The learner manual, shaped as Heropa Sections and Exercises |
| `tools/manual-to-html.py` | Turns the manual into HTML for Heropa |
| `heropa-html/` | The output of that script. Do not edit it by hand. |
| `docs/superpowers/` | The design and the plan this lab was first built from. They are kept as a record and do not describe later changes. |

The lab also makes four things that git ignores. They are `.env` with the settings and password of this VM, `certs/` with the certificate and the certbot logs, `letsencrypt/` with the state of certbot, and `nginx/html/qr/` with the QR picture.

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
   1. Tick **Allocate a permanent public IP address**. The lab address is made from this IP. With the box ticked the VM keeps its IP across a stop, so a learner's addresses keep working. Without it every start gives a new IP and new addresses. The section **When a learner comes back** below explains both cases.
   2. Add inbound rules for TCP 80 and TCP 443 from `0.0.0.0/0`. Let's Encrypt checks over port 80 from addresses it does not publish, so that rule cannot be narrowed.

   Leave outbound traffic allowed. The first build needs it for the images, and anything a learner adds beyond the codelab is downloaded.

Learners open the lab in tabs of their own browser, not in Heropa interface tabs. A Heropa Website tab takes one fixed URL, and each learner's address is different.

## Step 3 · Prepare the VM

Launch an environment from the template and open the VM's terminal.

1. Put this repository on the VM and run the provisioning script.

   ```bash
   git clone https://github.com/qiarie/heropa-fhir-engine-codelab.git ~/heropa-fhir-engine-codelab
   cd ~/heropa-fhir-engine-codelab
   sudo ./provision-heropa.sh
   ```

   It installs Docker, pulls nginx, certbot, HAPI FHIR and curl, and builds the workspace image. The build clones the codelab, downloads every dependency and compiles the app twice, so allow around fifteen minutes.

2. Pick up the new group, then start the lab once.

   ```bash
   newgrp docker
   ./lab-init.sh
   ```

   It prints the Editor address, the editor password, the App preview address and the FHIR server address. The password is a code of four digits, made once for each VM.

3. Open the Editor and App preview addresses in your own browser and walk the learner manual from start to finish.

4. Remove everything that belongs to this one VM, keeping the images.

   ```bash
   ./lab-init.sh --clean
   docker image ls
   ```

   `--clean` stops the lab, deletes the volume with your test edits and the FHIR server with its data, and removes `.env` and the certificate. Without it every learner would share one editor password and start from your code. It keeps the `letsencrypt` folder, which is harmless in the template because each learner's VM has a different address and asks for its own certificate.

5. Save the environment as a new template and use that saved template in the course.

### What the learner's first run costs

`./lab-init.sh` on a fresh VM takes two to three minutes. Most of it is the FHIR server starting, and the rest is the certificate request and Docker copying the checkout and the Gradle cache into the learner's volume. The App preview tab shows the starter app as soon as the first build finishes, which is quick because the image already built it.

## Step 4 · Create the policy

| Setting | Value |
|---|---|
| Access period | 3 hours |
| Limit Active time | On, 2 hours |
| Idle action | Stop the VMs after 30 minutes idle |

A stopped VM keeps its disk, so the learner's code is still in the volume, and all four containers start again with the VM. The FHIR server needs two to three minutes after a restart, and it comes back with the three test patients in their first state.

### When a learner comes back

What a returning learner has to do depends on the **Allocate a permanent public IP address** box from Step 2.

| | Box ticked | Box not ticked |
|---|---|---|
| IP after a stop and start | The same | A new one |
| Editor and App preview addresses | Keep working | Stop working, since they are made from the IP |
| What the learner does | Starts the VM and reloads the tabs | Starts the VM, runs `./lab-init.sh` and opens the new addresses |
| Certificate requests | One, at the first start | One at every start |

Tick the box. It spares learners the extra step, and it keeps the lab away from the certificate limits described below.

`./lab-init.sh` handles both cases, and a learner can run it at any time. It reads the IP again on every run and compares the address with the one from the last run. Its closing summary is written for the learner to act on. It always gives the Editor, App preview and FHIR server addresses and the password, and the lines under **Since the last run** say what changed.

```text
Since the last run
  Address    CHANGED. It was https://203-0-113-10.sslip.io
             Close the old Editor and App preview tabs. They no longer work.
             Open the two addresses above.
  Password   The same as before.
  Your code  Kept as you left it.
```

| Line | What it can say |
|---|---|
| Address | The same as before, or `CHANGED` with the old address and what to do |
| Password | Always the same. It is made once and kept in `.env`. With `IDE_AUTH=none` the line says no password is asked for. |
| Your code | Kept, or replaced with the starter after `--reset` |
| Server | Shown only after `--reset`, which puts the FHIR server back to the three test patients |
| Mode | Shown only when the lab moved from reduced mode back to full mode |

A first run has no last run to compare with, so it prints **First steps** instead. A run where nothing changed makes no certificate request. It takes a few seconds when the FHIR server is already up, and up to two minutes right after a restart, because it waits for the server to answer. A run after an IP change takes about a minute, and it recreates the workspace container so the editor learns the new address. The code is in the volume and is not touched.

The manual covers all of this under **Find your addresses again**, with the same sample output.

### Certificates and reduced mode

Every new IP means a new certificate, so `./lab-init.sh` makes up to three tries and stops at the first that works.

| Try | Certificate | Lab address | Mode |
|---|---|---|---|
| 1 | Let's Encrypt, for the sslip.io name | `https://203-0-113-10.sslip.io` | Full |
| 2 | Let's Encrypt, for the bare IP | `https://203.0.113.10` | Full |
| 3 | Self-signed | `https://203-0-113-10.sslip.io` | Reduced |

Try 1 counts against a limit that every sslip.io name in the world shares. Let's Encrypt has raised it to 250,000, so a refusal is rare but possible. Try 2 is counted per IP, apart from that limit. Its certificates last six days, which is longer than a lab.

In reduced mode the browser shows a warning page once, and the editor has no Guide, Build log or Output pane. Browsers refuse the editor's web views on an untrusted certificate, even after the warning is accepted. The Build log and Output buttons open browser pages instead, the guide opens as plain text, and a notice in the editor says why. The summary says `REDUCED MODE` in its first line and ends with a part headed `Why reduced mode`, which names the cause and lists the pages to use. The manual covers this under **If the lab starts in reduced mode**.

The script avoids needless requests.

- A certificate that still fits the current address and has two days left is kept, and nothing is asked.
- When Let's Encrypt refuses a request for being over a limit, the time it gives is saved in `certs/retry-after`. No request for that name or IP goes out before then. Delete the file to ask at once.
- A lab in reduced mode asks again on every later run outside that wait, and goes back to full mode automatically.
- The output of the last request is kept in `certs/certbot-name.log` and `certs/certbot-ip.log`.

A failed request no longer leaves the lab down. To see reduced mode without waiting for a failure, start a test lab with `LAB_CERT=self-signed`. To test the requests without touching the real limits, set `LAB_ACME_SERVER` to the Let's Encrypt staging directory.

## Step 5 · Add the content

`course-manual.md` is written for the Heropa lab and its web editor. The lab instructions are the main text. Anyone who wants to use Android Studio is sent to the published codelab on the website instead.

Heropa's course editor takes HTML, so the manual is converted before it is pasted in. Run `python3 tools/manual-to-html.py` from the repository root after every change to the manual. It writes the whole manual to `heropa-html/course-manual.html` and one file for each section to `heropa-html/sections/`. The first of those files holds the title and the introduction above step 1, and the last holds Troubleshooting. It also writes `heropa-html/get-started.html`, which holds the introduction and steps 1 and 2 in one page and ends with a note that sends the learner to the Guide in the Editor for the remaining steps. Publish that one page when the Heropa course should stop after the setup. Paste a file into the source view of the Heropa editor, not the visual view, so the editor keeps the markup as written. The script needs the `python3-markdown-it` package.

It is built on the published codelab. It keeps the codelab's explanations, steps and code, and leaves out the passages that only make sense in Android Studio or on a learner's own computer. Those were the list of tools, the download, starting the server with Docker Compose, the import into Android Studio, the Gradle sync, running on a device, the commands for other platforms, the three import prompts, the Android call with `10.0.2.2`, the WorkManager launcher and the `localhost` check in step 6. The lab text covers each of those jobs in the way the lab does it.

Three things from those passages are kept in another form.

* A link to the published codelab in the introduction, for anyone who would rather work in Android Studio
* The seven pictures, shown as plain pictures with a line that says what each one is. Six show the app on an Android phone and one shows the test patients on a FHIR server.
* One sentence saying the same code also runs on Android, iOS and Desktop, and one saying Android has its own sync launcher, each with the link

The lab text adds these things the original leaves to Android Studio or to a local setup.

* The exact file to open and how to reach it in the Explorer, for learners who have never seen a Gradle project
* Where each import line goes, since the web editor does not offer imports
* The lab form of each `localhost` address
* What to do when a sync fails, since the app itself shows only `Sync Failed`
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
| 8 | Show a registration form |
| 9 | Save the registered patient |
| 10 | Connect the workflow library to the engine |
| 11 | Propose tasks with the PlanDefinition |
| 12 | Congratulations |
| 13 | Troubleshooting |

Load it as Custom content by pasting the HTML of each exercise into the source view of the Heropa editor, or publish it through GitBook and add it as External content. The seven pictures load from GitHub at the pinned commit, so they need no upload.

The text taken from the published codelab keeps its own punctuation and line breaks. Only the text written for the lab follows this repository's prose rule.

## Step 6 · Create and publish the course

Create a course that ties together the template saved in Step 3, the policy from Step 4 and the content from Step 5, then publish it.

## The layout inside the editor

VS Code has no setting that opens files or pages when it starts, so a small extension in `workspace/ide/codelab-guide/` builds the layout. It is packaged into the image at build time and needs no marketplace.

| Area | How it is made |
|---|---|
| Guide | The Markdown preview that ships with the editor, opened on `course-manual.md`. The extension adds a Copy button to each code block except sample output, an Insert button to the blocks the manual marks, and shows one step at a time. |
| Build log | A web view that frames `/buildlog/` |
| Output | A web view that frames `/output/` |
| Terminal | An ordinary terminal, placed in a tab next to the output |

The Guide treats each second level heading of the manual as one step. A bar at the top has **Back**, **Next**, a list of the steps and a **Show all** switch, and the same two buttons sit under the text. The step on screen is remembered in the learner's browser. `preview/steps.js` in the extension does this by hiding the other steps, so the manual file needs no markup for it. A new second level heading in the manual becomes a new step on its own. Searching the Guide finds text in the step on screen only, unless **Show all** is on.

The status bar has six buttons. **Open app preview** opens `/preview/` in a new browser tab. **Build now** saves every open file and starts a build. **Guide**, **Build log** and **Output** reopen an area that was closed. **Fix imports** runs the `fix-imports` helper. The layout comes back after a page reload.

The app runs in one browser tab and the Output tab sits in another, so the output has to travel between them. No server is involved. The preview page listens to the app's console and saves each printed line in the browser's local storage for the lab address. The `/output/` page reads that storage, checks it again every second and a half, and asks the editor to bring the Output tab to the front when something new arrives. This works because both pages come from the same address, and it means the two tabs must be open in the same browser. The preview page drops the line the database worker prints for every query, which would bury everything else.

To change the default sizes, edit `LAYOUT` near the top of `extension/extension.js` and rebuild the image.

### The Insert button

A code block in the Guide gets an **Insert** button when the manual has a marker on the line above it. The button puts the block into the learner's file, so copy and paste becomes optional. The marker is an HTML comment, which the Guide does not show.

```markdown
<!-- codelab-insert file="shared/src/commonMain/kotlin/dev/ohs/fhir/codelab/FhirEngineSetup.kt" replace="// 4 Imports for the FHIR Engine" -->
```

| Part | Meaning |
|---|---|
| `file` | The file the code goes into, counted from the `codelabs` folder |
| `after` | The code goes on a new line under the line with this text |
| `replace` | The code takes the place of the line with this text |
| `then` | Used with `replace`. The next line is removed too when it starts with this text. |
| `through` | Used with `replace`. Every line down to the one with this text is removed too. |

The marker needs `file` and one of `after` and `replace`. A line of the file matches when its text is the same once the spaces around it are dropped. The new code takes the indent of that line. The file is left unsaved, and the learner saves it to start the build.

The button looks for text and never for a line number, so it still works when the learner's file has moved by a few lines. When the text is gone it says so and points to **Copy**. When the block is in the file already it selects it and changes nothing.

The Markdown preview gives a page inside it no way to call an extension, so the button works in a roundabout way. The extension writes one small signal file for each marked block under `~/.codelab/insert/`, and the button is a link to that file. The preview opens the link, the extension sees the new tab, closes it at once and makes the edit. The code is in `extension/insert.js`.

`tools/manual-to-html.py` drops the markers, so they never reach a Heropa page. In reduced mode the Guide is plain text and has no buttons.

The preview page knows when to reload because the build watcher writes its state to a small file, served at `/app-status.json`. The page polls it every second and a half. It can show what the app prints because it frames the app from the same address, which lets it listen to the app's console.

The app, the FHIR server, the build log and the status file are served without a password. Only the editor asks for one, which is a code of four digits unless you set your own. The **Settings** section below covers the password and how to turn it off. The build log holds compiler output and nothing secret.

The manual is mounted into the workspace container, not copied into the image. After editing it on the VM, run `docker compose restart workspace` and reload the Editor tab.

## Settings

Every setting of a lab lives in `.env`, next to `lab-init.sh`. The script copies `.env.example` to `.env` on its first run, and the comments in that file describe each setting and its options, so `.env` documents itself.

- To change a setting on one lab, edit `.env` and run `./lab-init.sh` again.
- To change a default for every lab started from a template, edit `.env.example` before saving the template, because `--clean` removes `.env`.
- To change a setting for one run only, put it in front of the command, as in `LAB_CERT=none LAB_HOST=localhost ./lab-init.sh`. The script writes `IDE_AUTH`, `IDE_PASSWORD`, `LAB_CERT` and the two ports back to `.env`, so those stay for later runs. Any other setting given this way lasts for that run only.

Every value goes inside double quotes.

The addresses in this document and in the manual, such as `203-0-113-10.sslip.io` and `203.0.113.10`, are placeholders from an address range reserved for examples. The password `4827` in the manual is a placeholder too. The manual says so beside each sample, so learners do not try to open them.

### Settings you may change

| Setting | Options | Default | What it does |
|---|---|---|---|
| `IDE_AUTH` | `password` or `none` | `password` | Whether the editor asks for a password |
| `IDE_PASSWORD` | Empty, or a password of your own | Empty | The code the editor asks for. Empty means the script makes a code of four digits and writes it here. |
| `LAB_CERT` | `letsencrypt`, `self-signed` or `none` | `letsencrypt` | How the lab gets its certificate |
| `LAB_HOST` | Empty, `localhost` or another name | Empty | The name the lab answers on. Empty means a name made from the public IP. |
| `PUBLIC_IP` | Empty, or an IPv4 address | Empty | The public IP of the VM. Empty means it is read from the metadata service on every run. |
| `LAB_HTTP_PORT` | A port number | `80` | The HTTP port nginx publishes |
| `LAB_HTTPS_PORT` | A port number | `443` | The HTTPS port nginx publishes |
| `CERTBOT_EMAIL` | Empty, or an email address | Empty | An address for the Let's Encrypt account |
| `LAB_ACME_SERVER` | Empty, or a directory URL | Empty | The service asked for certificates. Empty means the real Let's Encrypt. |
| `LAB_QR` | `on` or `off` | `on` | Whether the summary prints a QR code for the App preview |

### The options of IDE_AUTH

| Value | What the editor does | When to use it |
|---|---|---|
| `password` | Asks for the code in `IDE_PASSWORD` | On Heropa, and whenever you are unsure |
| `none` | Opens with no password | On your own machine, or where the inbound rules in Heropa let in one trusted network and nothing else |

With `none` the summary shows `none needed` instead of the password, and the manual tells learners what that means. The code stays in `.env`, so setting `IDE_AUTH` back to `password` brings the same one back.

Leave it on `password` unless you have a reason. The editor includes a terminal, so without a password anyone who reaches the address has a shell on the VM. The address is not a secret. It is made from the public IP, which scanners probe all day, and every Let's Encrypt certificate is listed in public logs under the lab's exact name within minutes. `./lab-init.sh` prints a warning whenever `none` is used on an address other than `localhost`.

### The options of IDE_PASSWORD

| Value | Result |
|---|---|
| Empty | The script makes a code of four digits on its first run, from 1000 to 9999, and keeps it for the life of the VM |
| A value of your own | Used as given. It may be any length. It must not hold a quote, a dollar sign, a backtick or a backslash. |

Four digits are easy to type, and the editor allows only a few wrong tries an hour, so guessing one within the hours a lab lasts is unlikely. A lab that stays up for weeks should get a longer password. To change the password of a running lab, edit the value and run `./lab-init.sh`.

### The options of LAB_CERT

| Value | Certificate | Mode | When to use it |
|---|---|---|---|
| `letsencrypt` | From Let's Encrypt, trusted by browsers. Falls back to a self-signed one when it cannot get one. | Full, or reduced after a fallback | On Heropa |
| `self-signed` | Made by the lab, not trusted by browsers | Reduced | To see what a learner gets after a fallback |
| `none` | None. The lab serves plain HTTP. | Full | Only with `LAB_HOST` set to `localhost`, on your own machine |

The section **Certificates and reduced mode** explains the tries and the fallback.

### The options of LAB_HOST and PUBLIC_IP

| `LAB_HOST` | `PUBLIC_IP` | Lab address |
|---|---|---|
| Empty | Empty | Made from the IP that the metadata service reports, as in `https://203-0-113-10.sslip.io`. This is the Heropa case. |
| Empty | An IP | Made from that IP, for a machine with no metadata service |
| `localhost` | Ignored | `http://localhost`, with `LAB_CERT` set to `none` |
| Another name | Ignored | That name, which must already point at the machine |

### The QR code and the options of LAB_QR

`./lab-init.sh` and `./lab-init.sh --info` print one QR code under the addresses, under the line `Scan the QR code to preview the app on your phone`. The start page of the lab shows the same code. A learner scans it with a phone or tablet to open the App preview there without typing the address. The Editor has no code, because the codelab needs a keyboard and a wide screen.

| Value | What the summary shows | When to use it |
|---|---|---|
| `on` | The addresses, then the code | On Heropa, unless the terminal cannot draw it |
| `off` | The addresses alone | When the Heropa terminal shows the code as broken characters |

- The code needs the `qrencode` package, which `provision-heropa.sh` installs. On a VM prepared before this was added, run `sudo apt-get install -y qrencode` once. Without the package the lab works as before and shows no code.
- The code in the terminal is drawn with block characters. It appears only when the output goes to a terminal, so a log file stays clean.
- The code on the start page is a picture, so `LAB_QR` does not affect it. The script draws it again on every run in `nginx/html/qr/`, which git ignores.
- A lab on `localhost` gets no code, because a phone cannot reach that address.

### Values the script writes

Do not edit these, because the next run replaces them.

| Setting | Values | What it holds |
|---|---|---|
| `LAB_URL` | An address | The address the Editor and App preview addresses are built on. It changes when the public IP changes. |
| `LAB_MODE` | `full` or `reduced` | Whether browsers trust the certificate in use |
| `LAB_NGINX_CONF` | `lab-https` or `lab-http` | Which nginx front is in use. `lab-http` goes with `LAB_CERT` set to `none`. |
| `LAB_FHIR_HTTPS` | `true` or `false` | The scheme the FHIR server writes into the links it returns. `false` goes with `LAB_CERT` set to `none`. |

## Resetting the lab

There are five ways to reset, from the lightest to the heaviest. None of them rebuilds an image.

| Command or button | Where | What it resets | What it keeps |
|---|---|---|---|
| `step reset` | Editor terminal | The seven codelab files, back to the starter | Every other file, and a copy of the replaced files in `~/backups` |
| `reset-server` | Editor terminal | The whole FHIR server. It is emptied and the test data is loaded again, so registered patients and their tasks are gone. | Nothing on the server |
| **Clear app data** | Top of the App preview tab | The app's own database in that browser | The code and the server |
| `./lab-init.sh --reset` | VM terminal | The whole learner volume and the FHIR server. The lab then starts again from the image, which takes two to three minutes. | `.env` with the password, the certificate and the images |
| `./lab-init.sh --clean` | VM terminal | Everything `--reset` does, plus `.env`, the password and the certificate. The lab stays stopped. | The images and the `letsencrypt` folder |

The lab keeps its state in three places, which are the code, the FHIR server and the browser. To get a lab that looks as if nobody has used it, without restarting anything, reset all three.

```bash
step reset
reset-server
```

Then click **Clear app data** in the App preview tab. The app rebuilds to `Hello World!` on its own.

Use `./lab-init.sh --reset` when a learner changed files outside the seven, or when the leftovers of the lighter route matter. No command on the VM can reach a browser, so click **Clear app data** after it as well.

Use `./lab-init.sh --clean` only before saving the VM as a template, as Step 3 describes. Do not run `./lab-init.sh` again after it, or the template carries a password and a volume.

`./lab-init.sh --info` resets nothing. It prints the addresses and the password again.

## Updating the codelab version

The workspace image is pinned to one commit of the codelab through `CODELAB_REF` in `workspace/Dockerfile`. The files in `workspace/solutions/` were written against that commit.

The pin is `455f438a548aa5a04cfca78c57612ca382a2d15e`, which is the head of [pull request 159](https://github.com/ohs-foundation/kotlin-fhir-engine/pull/159) as it stood on 26 November 2026. That pull request adds steps 8 to 11 and was still open and under review then, so it is not on the `main` branch and its code may change before it is merged. Once it is merged, move the pin to the merge commit and follow the steps below for whatever changed in between.

To move to a newer commit, do these in order.

1. Change `CODELAB_REF` in `workspace/Dockerfile`.
2. Update the files in `workspace/solutions/` to match the new codelab text. `starter/` holds the published starter files with the three lab changes described above. The image build copies them over the checkout and commits them.
3. Copy the files in the new `codelabs/data/` folder to `hapi/`, and match the HAPI image version in `docker-compose.yml` and `provision-heropa.sh` to the codelab's own compose file.
4. Carry the changes in the new `codelabs/README.md` over to `course-manual.md`, keeping the lab text and leaving out the passages that apply only to Android Studio. Update the commit in the picture addresses and the repository links.
5. Check the line numbers the manual quotes, and the names and imports in `fix-imports` and `codelab-hints`.
6. Rebuild the image, walk the manual again and save a new template.

## Testing without Heropa

The lab runs on any machine with Docker. This starts it on `http://localhost:8080` over plain HTTP.

```bash
docker build -t engine-codelab-workspace:local workspace
LAB_HOST=localhost LAB_CERT=none LAB_HTTP_PORT=8080 LAB_HTTPS_PORT=8443 ./lab-init.sh
```

Pick other ports if those two are taken. The FHIR server is not published on the machine, so it never clashes with a port.

Browsers treat `http://localhost` as a secure page, so the editor and the browser database work in full without a certificate. `LAB_CERT=self-signed` gives reduced mode, not the full editor. The editor's web views, including the guide pane, need a service worker, and browsers refuse to register one on a certificate they do not trust, even after you accept the warning. On Heropa the Let's Encrypt certificate is trusted, so this does not arise.

## Troubleshooting

| Symptom | Fix |
|---|---|
| The guide pane shows `Could not register service worker` | The page is on a certificate the browser does not trust, and the editor did not start in reduced mode. Run `./lab-init.sh` again so the mode and the certificate agree. On your own machine use `LAB_CERT=none`. |
| The lab starts in `REDUCED MODE` | Read the reason in the message. For port 80, check the inbound rules for TCP 80 and 443 and that the VM has a public IP. For a limit, wait until the time given. The details are in `certs/certbot-name.log` and `certs/certbot-ip.log`. Then run `./lab-init.sh` again. |
| The App preview tab stays on the waiting page | Read the build with `docker exec engine-workspace build-log`. |
| `/fhir/Patient` says the FHIR server is still starting | It takes two to three minutes. If it lasts longer, read `docker compose logs hapi`. |
| `/fhir/Patient` shows a `total` of 0 | Read `docker compose logs seed`. To load the patients by hand, run `docker exec engine-workspace reset-server`. |
| The app loads but never shows its first screen | The isolation headers are missing. Check them with `curl -sI <lab address>/app/`. |
| A build stops with `returns 127` | `libatomic1` is missing from the image. The Dockerfile installs it, so the image was changed. |
| The editor asks for a password nobody has | Run `./lab-init.sh --info`. It prints the addresses and the password without restarting anything. |
| A learner broke their code beyond repair | In the editor terminal run `step reset`, or on the VM run `./lab-init.sh --reset`. |
| Builds are killed or the VM swaps | The VM has less than 16 GB. Use a larger instance type. |
