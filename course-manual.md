# Manage FHIR resources using the Kotlin FHIR Engine

This guide takes you through the codelab on the Heropa lab, where you write the code in an editor in your browser and the app runs as a web page. A FHIR server for the app to talk to is already running in your lab. You install nothing.

It is built on the [published codelab](https://ohs-foundation.github.io/ohs-docs/tutorials-and-codelabs/engine/), which was written for Android Studio on your own computer. This guide covers the lab only. If you would rather work in Android Studio, follow the [published codelab](https://ohs-foundation.github.io/ohs-docs/tutorials-and-codelabs/engine/) instead of this guide.

The codelab text comes from the [Kotlin FHIR Engine](https://github.com/ohs-foundation/kotlin-fhir-engine) project under `codelabs` directory and is used under the Apache License 2.0.

## 1. Before you begin

### What you'll build

In this codelab, you're going to build a Kotlin Multiplatform app with the Kotlin FHIR Engine. Your
app will use the engine to download FHIR resources from a FHIR server, and upload any local changes
to the server. The same code runs on Android, iOS, Desktop (JVM) and Web (Wasm).

### What you'll learn

*   How to run a local HAPI FHIR server with Docker
*   How to integrate the Kotlin FHIR Engine into your Kotlin Multiplatform application
*   How to use the Sync API to download and upload FHIR resources
*   How to use the Search API
*   How to use the Data Access APIs to create, read, update, and delete FHIR resources locally

On the lab the HAPI FHIR server is started for you, so you skip the first of these. The block in part 2 shows how the published codelab does it.

### What you'll need

On the lab you need only a recent version of Chrome, Edge, Firefox or Safari, in an ordinary window. The app keeps its data in the browser, which private or incognito windows may not allow.

You do not need to know Kotlin. Every change is given in full, and this guide says exactly which file to open and where to put each line.

This codelab is focused on the
[Kotlin FHIR Engine](https://github.com/ohs-foundation/kotlin-fhir-engine). Non-relevant concepts
and code blocks are glossed over and are provided for you to simply copy and paste. If you haven't
built a Kotlin Multiplatform app before, you can start by
[creating your first Compose Multiplatform app](https://www.jetbrains.com/help/kotlin-multiplatform-dev/compose-multiplatform-create-first-app.html).

## 2. Get the code and start a FHIR server

### Start your lab

1. Open the terminal of your lab VM in Heropa.
2. Start the lab.

   ```bash
   cd ~/engine-codelab
   ./lab-init.sh
   ```

3. Wait two to three minutes. Most of that is the FHIR server starting. The command ends with a summary like the example below. The addresses and the password in the example are placeholders and do not work. Use the ones your own terminal prints.

   ```text
   ------------------------------------------------------------------------
   The lab is ready. Open these in the browser on your own computer.

     Editor            https://203-0-113-10.sslip.io/ide/
     Editor password   4827
     App               https://203-0-113-10.sslip.io/preview/
     FHIR server       https://203-0-113-10.sslip.io/fhir/Patient

   First steps
     1. Open the Editor address and enter the password.
     2. Click Open app at the very bottom of the Editor. The app opens in a
        second tab.

   Lost these details? Run ./lab-init.sh --info to print them again.
   The tabs stopped loading? Run ./lab-init.sh again. It is safe at any time.
   ------------------------------------------------------------------------
   ```

**The addresses and password in this manual are examples only.** Wherever you see `203-0-113-10.sslip.io`, `203.0.113.10` or the password `4827`, use the values from your own summary instead. Your addresses and password are your own. You can get them back at any time, and the section **Find your addresses again** below explains how.

The part of each address before `/ide/` is your lab address. In the example it is `https://203-0-113-10.sslip.io`. This guide says "your lab address" wherever the published codelab says `http://localhost:8080`.

### Open the editor and the app

You work in two browser tabs, one for the Editor and one for the App. Open both in the same browser, because the app's output travels between them through that browser.

1. Open the **Editor** address in a new tab. Type the editor password, which is a code of four digits, and press **Submit**. If the summary shows `none needed` instead of a password, the Editor opens without asking.
2. In the bar at the very bottom of the Editor, click **Open app**. The app opens in a second tab. If your browser blocks the new tab, allow it, or open the **App** address yourself.

If you have room, put the two tabs side by side in separate windows.

The Editor tab has six areas. The last three share the space under the code, and you switch between them by clicking their tabs.

| Area | Where | What it is for |
|---|---|---|
| Explorer | Far left | The project files |
| Code | Top centre | The file you are changing |
| Build log | Bottom centre | Shows each build, whether it worked and which steps are still to do |
| Output | Bottom centre, the tab next to Build log | Shows what the app prints. From step 4 on that is every request the app sends to the FHIR server, and the reason when a sync fails. |
| Terminal | Bottom centre, the tab next to Output | For typing commands |
| Guide | Right | This guide |

You can drag the borders between the areas to resize them. The bar at the very bottom has six buttons.

| Button | What it does |
|---|---|
| **Open app** | Opens the App tab |
| **Build now** | Saves every open file and builds the app straight away. You rarely need it, because saving a file starts a build automatically. |
| **Guide** | Brings the Guide back if you closed it |
| **Build log** | Brings the Build log back if you closed it |
| **Output** | Brings the Output tab back if you closed it |
| **Fix imports** | Adds the import lines your code needs. A later part explains imports. |

The App tab has a bar along the top and a strip along the bottom.

| Control | What it does |
|---|---|
| Status dot | Green when the app matches your code, amber while a build runs, red when the last build failed |
| **Auto refresh** | When ticked, the app reloads automatically after every successful build |
| **Refresh** | Reloads the app now |
| **Clear app data** | Empties the database the app keeps in your browser, then reloads the app. The patients on the FHIR server are not touched. |
| **Output** | The strip along the bottom, which shows whatever the app prints. The Output tab in the Editor shows the same thing. |

### Find your addresses again

Come here when you return to the lab after a break, when the Editor or App tab stops loading, or when you have lost the addresses or the password.

The lab VM stops when you close the course, when you stop it yourself, and when it sits idle for a while. Your code stays on it. The VM is set up to keep the same IP address, so the same addresses normally work again once it is running.

1. Open the course in Heropa and start the VM if it is stopped. Give it two to three minutes, because the FHIR server takes that long to start.
2. Reload the Editor and App tabs. If they load, you are done.
3. If they do not load, or you no longer have the addresses, open the terminal of the VM and run the same two commands as before.

   ```bash
   cd ~/engine-codelab
   ./lab-init.sh
   ```

4. Read the summary it prints. The lines under **Since the last run** tell you what to do.

When the address is the same, the summary says so. Reload your tabs, or open the addresses again.

```text
Since the last run
  Address    The same as before. Tabs you still have open work again after
             a reload.
  Password   The same as before.
  Your code  Kept as you left it.
```

When the VM came back with a different IP address, the summary says `CHANGED` and shows the old address. The address in this example is a placeholder. Close the old Editor and App tabs, because they no longer work, and so do bookmarks to them. Open the new **Editor** address from the top of the summary, enter the password, and click **Open app**.

```text
Since the last run
  Address    CHANGED. It was https://203-0-113-10.sslip.io
             Close the old Editor and App tabs. They no longer work. Open
             the two addresses above.
  Password   The same as before.
  Your code  Kept as you left it.
```

| What | After the VM restarts |
|---|---|
| Editor and App addresses | Normally the same. The summary says `CHANGED` when they are not. |
| Editor password | Always the same |
| Your code | Always kept as you left it |
| FHIR server address | Changes together with the other two, since it is the same address followed by `/fhir/` |
| FHIR server data | Goes back to the three test patients. Click **Clear app data** and then **Sync** in the App tab, so the app and the server agree again. |
| Build log and Output | Start empty, and fill again at the next build and the next **Sync** |

The command is safe to run at any time and as often as you like. It changes nothing when the address is the same. It always waits for the FHIR server to answer, which takes up to two minutes after a restart. When the address changed it also gets a certificate for the new address.

Always copy the addresses from the summary. They are made from the IP address of the VM, normally with dashes instead of dots and `.sslip.io` at the end, so an example IP of `203.0.113.10` would give `https://203-0-113-10.sslip.io/ide/`. Sometimes the summary shows the plain IP, such as `https://203.0.113.10/ide/`, with a note that says why. Those addresses work in exactly the same way.

### If the lab starts in reduced mode

The Editor needs a certificate that your browser trusts. The lab asks for one each time the address changes. Occasionally it cannot get one, usually because the service that issues them is over its limit. The lab then makes its own certificate and starts in **reduced mode**, and the summary from `./lab-init.sh` opens with the words `REDUCED MODE`. It also gives the reason, the pages to use, and when to try again.

Your code, the build and the app all work in reduced mode. Two things are different.

1. Your browser shows a warning page the first time you open the Editor address. Click **Advanced**, then **Proceed**. You do this once. The warning appears because the lab made its own certificate, and it is expected here.
2. The Editor has no Guide, Build log or Output area, because browsers block them on a certificate they do not trust. A notice in the Editor says so. Use these in their place.

| In full mode | In reduced mode |
|---|---|
| Guide area in the Editor | This manual in Heropa. The **Guide** button also opens it in the Editor as plain text. |
| Build log area in the Editor | The **Build log** address that `./lab-init.sh` prints, in a separate browser tab. The **Build log** button opens it. |
| Output area in the Editor | The **Output** strip along the bottom of the App tab |

Everything else in this manual applies as written. Where a step says to look at the Build log or the Output tab, look at the page from the table.

To get back to full mode, run `./lab-init.sh` again later. When it was refused for being over a limit, the summary gives the time to try again under **To get full mode**. That run asks for a certificate again and puts the lab back in full mode when it gets one. The addresses may change when that happens, so open the ones it prints.

### Download the code

There is nothing to download on the lab. The code is already there, and the Editor opens on the `codelabs` folder. The Explorer on the left shows what is inside it.

### Start a local FHIR server with test data

[HAPI FHIR](https://hapifhir.io/hapi-fhir/) is a popular open source FHIR server. We use a local
HAPI FHIR server in our codelab for the app to connect to.

On the lab the server is already running, and three test patients are already loaded into it. You run no Docker command. The server answers at your lab address followed by `/fhir/`.

To verify that the test data is available on the server, open the **FHIR server** address that `./lab-init.sh` printed, which is your lab address followed by `/fhir/Patient`, in a new browser tab. You should see a FHIR Bundle as the search result with a `total` count of 3.

If the page says the FHIR server is still starting, wait a minute and reload it.

The picture below shows that page on a local server.

![The test patients as the FHIR server returns them](https://raw.githubusercontent.com/ohs-foundation/kotlin-fhir-engine/697412d04157980fc24eb3fbb2e8e5c479b0f0ee/codelabs/images/image5.png)

The test patients are in `data/patients.json`, which you can open from the Explorer. To put the server back to them, for example to run the update step again, type this in the **Terminal** tab of the Editor.

```bash
reset-server
```

The server has no password. It holds only these made up patients, so do not put real data on it.

## 3. Set up the project

### Project structure

| Module       | Contents                                                                                                                                                    |
|:-------------|:------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `shared`     | Kotlin Multiplatform module. `commonMain` holds the engine setup, sync, view model and UI. The other source sets hold each platform's entry point and sync. |
| `androidApp` | Android application. `FhirApplication` initializes the engine and `MainActivity` shows `App()`.                                                             |
| `iosApp`     | Xcode project for iOS. It shows `App()` through `MainViewController()` in `shared/iosMain`.                                                                 |

The platform entry points are already written for you. Everything you'll write in this codelab goes
into five files in `shared/src/commonMain/kotlin/dev/ohs/fhir/codelab/`:

*   `FhirEngineSetup.kt`
*   `DownloadWorkManagerImpl.kt`
*   `AppFhirSyncTask.kt`
*   `PatientListViewModel.kt`
*   `PatientListScreen.kt`

Each place you'll change is marked with a numbered comment, such as
`// 4 Replace with code from the codelab to initialize the FHIR Engine.` The number tells you which
step of the codelab adds the code.

A path such as `shared/src/commonMain/kotlin/dev/ohs/fhir/codelab/` tells you which folders to open in the Explorer, from left to right. Click a folder to open it, and click a file to show it in the Code area.

**To open one of the five files**

`FhirEngineSetup.kt` is already open when the Editor starts. For the others, open `shared` in the Explorer, then `src`, then `commonMain`, then the folder shown as `kotlin/dev/ohs/fhir/codelab`, and click the file. All five sit side by side in that folder. Each file you open gets its own tab above the code.

The same folder holds three more files, `App.kt`, `ForegroundSyncLauncher.kt` and `SyncLauncher.kt`. You do not change those.

### Import the app into Android Studio

There is nothing to import on the lab. The Editor tab takes the place of Android Studio, and the project is already open in it.

### The Kotlin FHIR Engine dependency

For your convenience, the Kotlin FHIR Engine dependencies have already been added to the
`commonMain` source set of `shared/build.gradle.kts`:

```kotlin
kotlin {
  sourceSets {
    commonMain.dependencies {
      api("dev.ohs.fhir:fhir-engine:2.0.0-alpha05")
      api("dev.ohs.fhir:fhir-model-r4:1.0.0-rc03")
      // ...
    }
  }
}
```

Because the dependencies are in `commonMain`, Gradle picks the right artifact for each target
platform.

The FHIR model is [Kotlin FHIR](https://github.com/ohs-foundation/kotlin-fhir), not HAPI. Kotlin
FHIR resources are immutable. To change a resource, make a copy with `copy(...)`.

You change nothing in this part. It only shows what is already in the project.

### Sync your project with Gradle files

There is nothing to do on the lab. Every build the lab runs reads the Gradle files again.

### Run the starter app

The starter app is already running on the lab as a web page. Look at the App tab.

Because the FHIR Engine is not initialized yet, the app shows a `Hello World!` screen. As you can
see there isn't much here yet, so let's get right into creating the FHIR Engine!

The pictures in this guide show the app on an Android phone. The web page on the lab has the same parts and looks slightly different.

![The Hello World app on an Android phone](https://raw.githubusercontent.com/ohs-foundation/kotlin-fhir-engine/697412d04157980fc24eb3fbb2e8e5c479b0f0ee/codelabs/images/image6.png)

### Run the app on other platforms

The lab runs the Web (Wasm) version of the app. You do not type any command. The lab builds the app automatically every time you save a file, as the next part explains.

The app is built with Kotlin Multiplatform, so the same code also runs on Android, iOS and Desktop. The [published codelab](https://ohs-foundation.github.io/ohs-docs/tutorials-and-codelabs/engine/) shows how to run it on each of them.

### How to run the app

You do the same four things for every step of the codelab.

1. Change a file in the Code area.
2. Save it with Ctrl+S, or Cmd+S on a Mac. Saving starts a build.
3. Watch the Build log under the code. It prints `Building the app` and then, after up to a minute, `BUILD OK`.
4. Switch to the App tab. It has reloaded automatically and shows the new version.

**Builds are automatic.** The lab watches the project files. Every time you save one, it builds the app again and the App tab reloads. There is no Run button to press and no command to type. A change you have not saved is not built. A white dot on a file's tab marks unsaved changes, so while you see it the app does not have that change yet.

If you save again while a build is running, the lab finishes that build and then runs one more, so your latest change is never missed.

### Start a build yourself

You rarely need to, but you can start a build without changing a file. Do this when you are not sure a build ran, when the Build log shows nothing new after a save, or when you want to see the result of the last build again.

| Way | What to do |
|---|---|
| Button | Click **Build now** in the bar at the very bottom of the Editor. It saves every open file first, then builds. |
| Command | Click the **Terminal** tab, type `build` and press Enter. This builds the files as they were last saved. |

Either way, the build appears in the Build log like any other, and ends with `BUILD OK` or `BUILD FAILED`. When nothing changed since the last build, it finishes in a few seconds.

After each successful build, the Build log also prints a **Still to do** list of the numbered comments that are still in the code. It gets shorter as you go and is a quick way to see where you are.

Some steps change more than one file. Save each file as you finish it. A build in between may fail because the other files are not done yet, and that is fine. The build after your last save is the one that counts.

### When a build fails

If the Build log prints `BUILD FAILED`, look just above it for lines that start with `e`. Each one names the file, the line number and the problem. Under them, a **What to do** list explains the common ones in plain words. Fix the file and save again. The App tab keeps showing the last version that worked.

### If you have used Android Studio

This table shows what takes the place of each thing you know.

| In Android Studio | On the lab |
|---|---|
| Open Android Studio | Use the Editor tab |
| Click **Run** in the Android Studio toolbar | Save the file, wait for `BUILD OK`, look at the App tab. **Build now** does the same without a change. |
| Select **Sync Project with Gradle Files** | Nothing. Every build reads the Gradle files. |
| Read Logcat | Read the **Output** tab in the Editor, next to the Build log |
| Tap **Sync** or **Update** | Click **Sync** or **Update** |
| `http://localhost:8080/fhir/` | Your lab address followed by `/fhir/` |
| `docker compose down` and `docker compose up -d` | Type `reset-server` in the **Terminal** tab |
| Android Studio prompts you to add the necessary imports | Paste the import lines yourself, under the numbered comment the step names |

### What this editor does not do for you

The web editor is simpler than Android Studio, which quietly does several jobs as you type. Read this once, because it explains most of the errors people hit.

| Android Studio does this | On the lab |
|---|---|
| Offers to add an import when you paste code | You add each import line yourself |
| Picks between two types with the same name | You must use the exact import line from the step |
| Underlines mistakes in red as you type | Nothing is underlined. Mistakes show in the Build log after you save. |
| Completes names as you type | No completion. Copy and paste the code. |
| Tidies indentation and removes unused imports | Nothing is tidied. Indentation does not affect the build, and an unused import is harmless. |

**What an import is**

Code refers to things by short names, such as `FhirEngineProvider`. An import line says which library a short name comes from. If the import is missing, the build fails with `Unresolved reference`.

**Where import lines go**

All import lines of a file sit together near its top, each starting with the word `import`. Right under them, in each file that needs new imports, the lab has put a numbered comment. This is the top of `AppFhirSyncTask.kt`.

```kotlin
import dev.ohs.fhir.engine.sync.FhirSyncTask
import dev.ohs.fhir.engine.sync.upload.UploadStrategy
// 5.2 Imports for the sync task
```

Each step tells you which of these comments to paste its imports under. You never have to hunt for the right spot. The order of import lines does not matter.

**One name, two meanings**

Two different things in this codelab are both called `String`.

| What it is | How the code names it | Import line |
|---|---|---|
| Kotlin's own text type | `String` | None. It is always there. |
| The FHIR text type, which wraps a value and can carry extensions | `FhirString` | `import dev.ohs.fhir.model.r4.String as FhirString` |

The ending `as FhirString` gives the FHIR type a second name so the two do not clash. If a file imports `dev.ohs.fhir.model.r4.String` without that ending, every `String` in the file means the FHIR one, and the build fails with errors about type mismatches. Step 6 is where this import comes in.

**Help when you are stuck**

| Help | What it does |
|---|---|
| **Fix imports** button, at the bottom of the Editor | Adds every import the code in the five files needs and repairs the `String` import. This is the closest thing to what Android Studio does. |
| `step 4`, `step 5`, `step 6` or `step 7`, typed in the **Terminal** tab | Replaces the five files with a working version of the code as it stands at the end of that step |
| `step reset`, typed in the **Terminal** tab | Puts the five files back to the starter code |
| `reset-server`, typed in the **Terminal** tab | Puts the three test patients on the FHIR server back to their first state |
| **Clear app data**, at the top of the App tab | Empties the database the app keeps in your browser |

Your own files are copied to the `backups` folder in your home folder before `step` or **Fix imports** change them.

## 4. Create the FHIR Engine instance

In this step, you'll initialize the FHIR Engine with the address of your local FHIR server.

Start with the five imports this step needs. The web editor does not add imports for you, so you paste them in yourself, before any other code.

1. Go to `shared/src/commonMain/kotlin/dev/ohs/fhir/codelab/FhirEngineSetup.kt`. It is the file that is open in the Code area.
2. Find the `// 4 Imports for the FHIR Engine` comment. It is on line 18, just under the line that starts with `package`.
3. Replace that comment with the following code. The first line puts the comment back, so the imports end up right under it.

   ```kotlin
   // 4 Imports for the FHIR Engine
   import dev.ohs.fhir.engine.DatabaseErrorStrategy
   import dev.ohs.fhir.engine.FhirEngineConfiguration
   import dev.ohs.fhir.engine.FhirEngineProvider
   import dev.ohs.fhir.engine.ServerConfiguration
   import dev.ohs.fhir.engine.sync.remote.HttpLogger
   ```

The `// 4 Imports` comment is not in the published codelab. The lab adds it to the starter code to mark the place.

1. Open `shared/src/commonMain/kotlin/dev/ohs/fhir/codelab/FhirEngineSetup.kt`. Find the
    `// 4 Replace with code from the codelab to initialize the FHIR Engine.` comment in
    `initFhirEngine` and replace it with the following code:

    ```kotlin
    // 4 Initialize the FHIR Engine
    FhirEngineProvider.init(
      FhirEngineConfiguration(
        databaseErrorStrategy = DatabaseErrorStrategy.RECREATE_AT_OPEN,
        serverConfiguration =
          ServerConfiguration(
            baseUrl = baseUrl,
            httpLogger =
              HttpLogger(if (debug) HttpLogger.Level.BODY else HttpLogger.Level.BASIC),
          ),
        storageDirectory = storageDirectory,
      ),
      platformContext,
    )
    ```

    Notes:
    * `platformContext`: the application `Context` on Android, `Unit` on other platforms.
    * `baseUrl`: the FHIR server's base URL.
    * `httpLogger`: logs the requests to the server. The logs show up in Logcat on Android, the
      Xcode console on iOS, the terminal on Desktop and the browser console on Web.
    * `storageDirectory`: where the database is stored. Used on desktop and web only.
    * `RECREATE_AT_OPEN`: if the database fails to open, the engine deletes it and makes a new one.
    * `enableEncryption = true` encrypts the database with SQLCipher. It is supported on Android
      only.

    The comment is on line 35 now that the imports are in, on the last line before the closing brace of the file. Press Ctrl+F and type `// 4 Replace` to jump to it. Select that one line, delete it and paste the block above where it was. The new block starts with its own numbered comment, `// 4 Initialize the FHIR Engine`.

    On the lab you do not need the browser console. The lab copies what the app logs there into the **Output** tab of the Editor.

2. Each platform calls `initFhirEngine` once at startup. The starter already has these calls.

    On the lab the web entry point makes the call, in `shared/src/wasmJsMain/kotlin/dev/ohs/fhir/codelab/Main.kt`. You do not change it. The lab has changed one line of that file so the app finds the FHIR server at your lab address followed by `/fhir/`. The published file says `http://localhost:8080/fhir/`, which from your browser would mean your own computer.

    ```kotlin
    initFhirEngine(Unit, baseUrl = "${pageOrigin()}/fhir/", debug = true)
    ```

3. Get the engine anywhere with `FhirEngineProvider.getInstance(platformContext)`.

Now run it. Save `FhirEngineSetup.kt` with Ctrl+S, wait for `BUILD OK` in the Build log, then look at the App tab.

Now that the engine is initialized, run the app again. Instead of the `Hello World!` screen, you
should see the patient list. The list stays empty until you sync with the server in the next
step.

The page has a bar with **Sync** and **Update** buttons and a **Search by name** field. The buttons do nothing yet.

If the Build log prints `BUILD FAILED`, read the **What to do** list under the errors, or click **Fix imports** at the bottom of the Editor. If you would rather jump to the finished code, type `step 4` in the **Terminal** tab.

The picture below shows the empty patient list on an Android phone.

![The empty patient list on an Android phone](https://raw.githubusercontent.com/ohs-foundation/kotlin-fhir-engine/697412d04157980fc24eb3fbb2e8e5c479b0f0ee/codelabs/images/image7.png)

## 5. Sync data with the FHIR server

In this step, you'll download patients from the FHIR server into the local database, and upload
local changes back to the server.

This step changes four files. Each part below names its file, gives its imports first if it needs any, and then its code. Save each file when you finish its part. The app works once all four parts are in.

### Step 1: Define which resources to download

Open `DownloadWorkManagerImpl.kt` in `commonMain`. Make the three changes below in order, because each one moves the lines under it down.

Replace line 22 with the following code.

```kotlin
// 5.1 Import for the download manager
import dev.ohs.fhir.model.r4.Bundle
```

Replace lines 29 and 30, in `getNextRequest()`, with the following code.

```kotlin
// 5.1 Return the next download request
val url = urls.removeFirstOrNull() ?: return null
return DownloadRequest.of(url)
```

Replace lines 37 and 38, in `processResponse()`, with the following code.

```kotlin
// 5.1 Extract the resources from the response
if (response is Bundle && response.type.value == Bundle.BundleType.Searchset) {
  return response.entry.mapNotNull { it.resource }
}
return emptyList()
```

The class now looks like this. Save the file.

```kotlin
class DownloadWorkManagerImpl : DownloadWorkManager {
  private val urls = ArrayDeque(listOf("Patient"))

  override suspend fun getNextRequest(): DownloadRequest? {
    // 5.1 Return the next download request
    val url = urls.removeFirstOrNull() ?: return null
    return DownloadRequest.of(url)
  }

  override suspend fun getSummaryRequestUrls() = mapOf<ResourceType, String>()

  override suspend fun processResponse(response: Resource): Collection<Resource> {
    // 5.1 Extract the resources from the response
    if (response is Bundle && response.type.value == Bundle.BundleType.Searchset) {
      return response.entry.mapNotNull { it.resource }
    }
    return emptyList()
  }
}
```

This class has a queue of URLs to download. It extracts the resources from each returned bundle,
and the engine saves them in the local database.

### Step 2: Define how the app syncs

Open `AppFhirSyncTask.kt` in `commonMain`. Make the two changes below in order.

Replace line 23 with the following code.

```kotlin
// 5.2 Imports for the sync task
import dev.ohs.fhir.engine.FhirEngineProvider
import dev.ohs.fhir.engine.sync.AcceptLocalConflictResolver
import dev.ohs.fhir.engine.sync.upload.HttpCreateMethod
import dev.ohs.fhir.engine.sync.upload.HttpUpdateMethod
```

Replace lines 31 to 39, which are the `// 5.2 Replace` comment and the four functions under it, with the following code. Keep the closing brace on line 40.

```kotlin
// 5.2 Define the download manager, conflict resolver, FHIR Engine and upload strategy
override fun getDownloadWorkManager(): DownloadWorkManager = DownloadWorkManagerImpl()

override fun getConflictResolver(): ConflictResolver = AcceptLocalConflictResolver

override fun getFhirEngine(): FhirEngine = FhirEngineProvider.getInstance(platformContext)

override fun getUploadStrategy(): UploadStrategy =
  UploadStrategy.forBundleRequest(
    methodForCreate = HttpCreateMethod.PUT,
    methodForUpdate = HttpUpdateMethod.PATCH,
    squash = true,
    bundleSize = 500,
  )
```

Save the file.

Code that ends in `TODO()` builds without error and only fails when the app runs, so check that none is left. The **Still to do** list in the Build log names any that is.

Here, we've defined which download manager, conflict resolver, and FHIR Engine instance to use for
syncing. All platforms use this class.

Shared code starts a sync through the `SyncLauncher` interface. Each platform has its own
implementation, which is already in the starter:

* **Desktop, Web, and iOS:** `ForegroundSyncLauncher` runs `AppFhirSyncTask` with `runSync` in the
  app's coroutine. The sync stops if the app closes.

The lab runs the web app, so this is the launcher your app uses. A sync runs only while the App tab is open. The lab has added one line to `ForegroundSyncLauncher.kt`, which prints the reason when a sync fails so that you can read it in the Output tab.

On Android a different launcher keeps the sync running in the background. The [published codelab](https://ohs-foundation.github.io/ohs-docs/tutorials-and-codelabs/engine/) describes it.

### Step 3: Start the sync

Open `PatientListViewModel.kt`. Find the
`// 5.3 Replace with code from the codelab to start the sync.` comment in `triggerOneTimeSync()`
and replace it with the following code:

```kotlin
// 5.3 Start the sync
scope.launch { syncLauncher.oneTimeSync().collect { _pollState.emit(it) } }
```

The file is in the same folder as the others. The comment is on line 67, and you can press Ctrl+F and type `// 5.3` to jump to it. Replace that one line with the two lines above. This part needs no new import. Save the file.

This coroutine starts a one-time sync with the FHIR server, and forwards the state of the sync to
the UI.

### Step 4: Show when the sync finishes

Open `PatientListScreen.kt`. Find the
`// 5.4 Replace with code from the codelab to show a message when the sync completes.` comment in
`handleSyncJobStatus` and replace it with the following code:

```kotlin
// 5.4 Show a message when the sync completes
when (syncJobStatus) {
  is CurrentSyncJobStatus.Succeeded -> {
    viewModel.refreshPatients()
    snackbarHostState.showSnackbar("Sync Finished")
  }
  else -> {}
}
```

The file is in the same folder as the others. The comment is on line 95, and you can press Ctrl+F and type `// 5.4` to jump to it. Replace that one line with the block above. This part needs no new import. Save the file.

Here, when the sync finishes, the app reloads all patients from the local database with
`refreshPatients()`, which is already in the starter, and shows a message to the user.

Now run it. Wait for `BUILD OK` in the Build log, then go to the App tab and click **Sync**.

Now that everything is set up, run your app and tap **Sync**. If everything works correctly, you
should see the patients from your local FHIR server being downloaded and displayed in the app.

The list shows the three test patients, and the words **Sync Finished** appear at the bottom for a few seconds. The Output tab in the Editor shows the requests the app sent to the FHIR server and the answers it got.

If nothing appears in the app after a few seconds, the sync failed. The app shows nothing in that case, so look in two places.

* The **Output** tab in the Editor. A red line that starts with `Sync failed` or names `NotImplementedError` gives the reason. `NotImplementedError` means a `TODO()` is still in `AppFhirSyncTask.kt`. After fixing the code, wait for the app to reload before you click **Sync** again.
* The **Still to do** list in the Build log. Every `// 5` comment and every `TODO()` must be gone.

If you would rather jump to the finished code, type `step 5` in the **Terminal** tab.

The picture below shows the patient list after a sync, on an Android phone.

![The patient list after a sync on an Android phone](https://raw.githubusercontent.com/ohs-foundation/kotlin-fhir-engine/697412d04157980fc24eb3fbb2e8e5c479b0f0ee/codelabs/images/image8.png)

## 6. Modify and upload patient data

In this step, you'll swap the address cities of patients in `Wakefield` and `Taunton`, then upload
the changes to the FHIR server. All the code in this step goes in the `PatientListViewModel` class
in `PatientListViewModel.kt`.

Start with the two imports this step needs.

1. Open `PatientListViewModel.kt`.
2. Find the `// 6 Imports for changing patient data` comment on line 31, just under the import lines.
3. Replace that comment with the following code.

   ```kotlin
   // 6 Imports for changing patient data
   import dev.ohs.fhir.engine.search.StringFilterModifier
   import dev.ohs.fhir.model.r4.String as FhirString
   ```

Copy the second line exactly, with `as FhirString` at its end. The section "One name, two meanings" earlier in this guide explains why.

You'll also need the Kotlin FHIR `String` type. It has the same name as Kotlin's own `String`, so
add it by hand with an alias:

```kotlin
import dev.ohs.fhir.model.r4.String as FhirString
```

If you import `dev.ohs.fhir.model.r4.String` without the alias, it hides Kotlin's `String` and
parameters such as `city: String` no longer compile.

On the lab this line is the second of the two you just pasted, so there is nothing more to add.

### Step 1: Search for patients by city

Find the `// 6.1 Replace with code from the codelab to search for patients by city.` comment and
replace it with the following code:

```kotlin
// 6.1 Search for patients by city
private suspend fun searchByCity(city: String): List<Patient> =
  fhirEngine
    .search<Patient> {
      filter(
        StringClientParam("address-city"),
        {
          modifier = StringFilterModifier.MATCHES_EXACTLY
          value = city
        },
      )
    }
    .map { it.resource }
```

The comment is in `PatientListViewModel.kt`, a few lines under the `triggerOneTimeSync()` function. Press Ctrl+F, or Cmd+F on a Mac, and type `// 6.1` to jump to it. Select that one line, delete it and paste the block above where it was.

There are no generated search parameter constants, so use the FHIR search parameter name, here
`address-city`.

### Step 2: Change the city of a patient

Find the `// 6.2 Replace with code from the codelab to change the city of a patient.` comment and
replace it with the following code:

```kotlin
// 6.2 Change the city of a patient
private fun Patient.withCity(city: String): Patient =
  copy(
    address =
      address.mapIndexed { index, address ->
        if (index == 0) address.copy(city = FhirString(value = city)) else address
      },
  )
```

The comment is in the same file, just under the code you pasted for step 6.1. Press Ctrl+F and type `// 6.2` to jump to it, and replace that one line with the block above.

Kotlin FHIR resources are immutable, so this function makes a copy of the patient with the new
city.

### Step 3: Update the patients, then sync

Find the `// 6.3 Replace with code from the codelab to update the patients and sync.` comment in
`triggerUpdate()` and replace it with the following code:

```kotlin
// 6.3 Update the patients and sync
scope.launch {
  val patientsFromWakefield = searchByCity("Wakefield")
  val patientsFromTaunton = searchByCity("Taunton")

  patientsFromWakefield.forEach { fhirEngine.update(it.withCity("Taunton")) }
  patientsFromTaunton.forEach { fhirEngine.update(it.withCity("Wakefield")) }

  triggerOneTimeSync()
}
```

The comment is in the same file, inside the `triggerUpdate()` function under the code for step 6.2. Press Ctrl+F and type `// 6.3` to jump to it, and replace that one line with the block above.

After modifying the data locally, the app triggers a one-time sync to upload the changes to the
FHIR server.

Your `PatientListViewModel` class should now look like this:

```kotlin
class PatientListViewModel(
  private val fhirEngine: FhirEngine,
  private val syncLauncher: SyncLauncher,
  private val scope: CoroutineScope,
) {
  private val _pollState = MutableSharedFlow<CurrentSyncJobStatus>()
  val pollState: SharedFlow<CurrentSyncJobStatus> = _pollState

  private val _patients = MutableStateFlow<List<Patient>>(emptyList())
  val patients: StateFlow<List<Patient>> = _patients

  private var loadJob: Job? = null

  init {
    refreshPatients()
  }

  /** Loads all patients from the local database, sorted by given name. */
  fun refreshPatients() = showPatients {
    fhirEngine
      .search<Patient> { sort(StringClientParam("given"), Order.ASCENDING) }
      .map { it.resource }
  }

  /**
   * Shows the patients that [load] returns. Cancels the previous load, so an older search can't
   * replace the result of a newer one.
   */
  private fun showPatients(load: suspend () -> List<Patient>) {
    loadJob?.cancel()
    loadJob = scope.launch { _patients.value = load() }
  }

  fun triggerOneTimeSync() {
    // 5.3 Start the sync
    scope.launch { syncLauncher.oneTimeSync().collect { _pollState.emit(it) } }
  }

  // 6.1 Search for patients by city
  private suspend fun searchByCity(city: String): List<Patient> =
    fhirEngine
      .search<Patient> {
        filter(
          StringClientParam("address-city"),
          {
            modifier = StringFilterModifier.MATCHES_EXACTLY
            value = city
          },
        )
      }
      .map { it.resource }

  // 6.2 Change the city of a patient
  private fun Patient.withCity(city: String): Patient =
    copy(
      address =
        address.mapIndexed { index, address ->
          if (index == 0) address.copy(city = FhirString(value = city)) else address
        },
    )

  /** Swaps the city of patients in Wakefield and Taunton, then syncs the changes. */
  fun triggerUpdate() {
    // 6.3 Update the patients and sync
    scope.launch {
      val patientsFromWakefield = searchByCity("Wakefield")
      val patientsFromTaunton = searchByCity("Taunton")

      patientsFromWakefield.forEach { fhirEngine.update(it.withCity("Taunton")) }
      patientsFromTaunton.forEach { fhirEngine.update(it.withCity("Wakefield")) }

      triggerOneTimeSync()
    }
  }

  fun searchPatientsByName(nameQuery: String) {
    // 7 Replace with code from the codelab to search for patients by name.
  }
}
```

If your class does not match, you can select it from the line `class PatientListViewModel(` to the last closing brace of the file and paste the block above over it. Then save the file and wait for `BUILD OK`.

### Step 4: Test the functionality

1. Run your app and tap **Update**. You should see the address cities for patients `Aaron697` and
    `Abby752` swapped.
2. Open your lab address followed by `/fhir/Patient/` in a browser, which is the **FHIR server** address that `./lab-init.sh` printed. If that tab is still open, reload it. Verify that the address cities for
    patients `Aaron697` and `Abby752` are updated on the FHIR server.

Each click on **Update** swaps the two cities again, so a second click puts them back. To return the server to its first state at any time, type `reset-server` in the **Terminal** tab. Then click **Clear app data** in the App tab and click **Sync**, so the app holds the same data as the server again.

If you would rather jump to the finished code, type `step 6` in the **Terminal** tab.

## 7. Search for patients by name

In this step, you'll filter the patient list by the name typed in the search field.

Find the `// 7 Replace with code from the codelab to search for patients by name.` comment in
`searchPatientsByName` and replace it with the following code:

```kotlin
// 7 Search for patients by name
showPatients {
  fhirEngine
    .search<Patient> {
      if (nameQuery.isNotEmpty()) {
        filter(
          StringClientParam("name"),
          {
            modifier = StringFilterModifier.CONTAINS
            value = nameQuery
          },
        )
      }
    }
    .map { it.resource }
}
```

The comment is in `PatientListViewModel.kt`, inside the `searchPatientsByName` function at the end of the file. Press Ctrl+F, or Cmd+F on a Mac, and type `// 7` to jump to it, and replace that one line with the block above. This step needs no new import, because `StringFilterModifier` came in with step 6. Save the file and wait for `BUILD OK`.

Here, if `nameQuery` is not empty, the search returns only the patients whose names contain it.
`showPatients`, which is already in the starter, shows the result. Each letter you type starts a
new search, so `showPatients` cancels the previous search first. Otherwise an older search, such as
the one for the first letter, could finish last and replace the result.

Run your app again. You should now be able to enter a name, or part of a name, in the search field
to filter the list of patients.

On the lab, click in the **Search by name** field of the App tab and type `Abby`. The list shrinks to the one patient with that name. The search reads the database in your browser and sends nothing to the server, so nothing new appears in the Output tab.

If you would rather jump to the finished code, type `step 7` in the **Terminal** tab.

The picture below shows the list filtered by name, on an Android phone.

![The patient list filtered by name on an Android phone](https://raw.githubusercontent.com/ohs-foundation/kotlin-fhir-engine/697412d04157980fc24eb3fbb2e8e5c479b0f0ee/codelabs/images/image9.png)

## 8. Congratulations!

You have used the Kotlin FHIR Engine to manage FHIR resources in your app:

*   Use the Sync API to sync FHIR resources with a FHIR server
*   Use the Data Access API to create, read, update, and delete local FHIR resources
*   Use the Search API to search local FHIR resources

### What we've covered

*   How to run a local HAPI FHIR server with test data
*   How to add the Kotlin FHIR Engine to your Kotlin Multiplatform app
*   How to use the Sync API, Data Access API, and Search API of the Kotlin FHIR Engine

### Next steps

*   Run the codelab on the other platforms: Desktop, Web and iOS
*   Download other resource types by adding them to the `urls` queue in `DownloadWorkManagerImpl`
*   Add periodic sync. See [`engine-app`](https://github.com/ohs-foundation/kotlin-fhir-engine/tree/main/engine-app)
    for an example on every platform.
*   Explore the Search API. The [conformance](https://github.com/ohs-foundation/kotlin-fhir-engine/blob/main/docs/conformance.md)
    document lists the supported search parameter types, modifiers and prefixes.

The other platforms need tools the lab does not have. To try them, follow the [published codelab](https://ohs-foundation.github.io/ohs-docs/tutorials-and-codelabs/engine/) on your own computer. Here are some things you can try on the lab.

* In step 7, change `StringFilterModifier.CONTAINS` to `StringFilterModifier.STARTS_WITH`, save, and search for `by`
* In `PatientListViewModel.kt`, change `Order.ASCENDING` to `Order.DESCENDING` in `refreshPatients()`, save, and click **Sync**
* Click **Update**, then read the Output tab to see the request the app sent to the server for the two changed patients

## Troubleshooting

| Symptom | Fix |
|---|---|
| You saved a file and the Build log shows no new build | Check the file's tab for a white dot, which means it is not saved yet. Then click **Build now** at the very bottom of the Editor, or type `build` in the **Terminal** tab. |
| The App tab says the app is still building | Wait for `BUILD OK` in the Build log. The page reloads automatically. |
| The App tab did not change after a build | Check that **Auto refresh** is ticked, or click **Refresh**. If it still shows the old version, check that the Build log says `BUILD OK` and not `BUILD FAILED`. |
| `Unresolved reference` in the Build log | An import is missing or misspelled. Click **Fix imports**, or compare your imports with the ones the step gives. |
| Errors about a type mismatch on `String`, or on `city` | The file imports `dev.ohs.fhir.model.r4.String` without `as FhirString` at the end. Add the ending, or click **Fix imports**. |
| `Unresolved reference 'searchByCity'` or `'withCity'` | Step 6.1 or 6.2 is missing. Step 6.3 calls both. |
| `is not abstract and does not implement abstract member` | A function was deleted from `DownloadWorkManagerImpl` or `AppFhirSyncTask`. Paste the whole class from the step again. |
| `Expecting` or `Syntax error` | A bracket, brace or quote is missing or extra near the line number in the error. |
| The app still says `Hello World!` after step 4 | The build failed, or the `// 4 Replace` comment is still in `FhirEngineSetup.kt`. Read the Build log. |
| Clicking **Sync** does nothing | The sync failed. Read the Output tab for a red line that starts with `Sync failed` or names `NotImplementedError`, and the **Still to do** list in the Build log. A `TODO()` left in `AppFhirSyncTask.kt` is the usual cause. If the code is right, click **Refresh** in the App tab and try again. |
| The Output tab shows an error with status 502 or 503 after **Sync** | The FHIR server is still starting. Wait a minute and click **Sync** again. |
| **Sync** works but the list stays empty | Open the **FHIR server** address. If `total` is 0, type `reset-server` in the **Terminal** tab and sync again. |
| The cities in the app and on the server do not match | The server was reset or the VM was stopped while the app kept its own copy. Click **Clear app data** in the App tab, then **Sync**. |
| **Update** changed nothing | No patient is in `Wakefield` or `Taunton` in the app's data. Type `reset-server`, click **Clear app data**, then **Sync** and **Update**. |
| The app stays blank or never leaves its loading state | Use a current Chrome, Edge, Firefox or Safari in an ordinary window, not a private one. Then click **Clear app data**. |
| Nothing appears in the Output tab | Click **Sync** after the app has reloaded. Step 4 must be built for anything to print. The App tab and the Editor must also be open in the same browser, because the output travels between them through that browser. |
| The Guide, Build log or Output area is gone | Click its name in the bar at the very bottom of the Editor. |
| **Open app** does nothing | The browser blocked the new tab. Allow pop-ups for the lab address, or open the **App** address that `./lab-init.sh` printed. |
| The code is in a state you cannot fix | Type `step reset` in the **Terminal** tab, or `step` with the number of the last step you finished. |
| The Editor asks for the password again | Run `./lab-init.sh --info` in the Heropa terminal. It prints the same password without restarting anything. |
| You came back and the tabs do not load | The VM was stopped. Start it in Heropa, wait two minutes for the FHIR server and reload the tabs. Then click **Clear app data** and **Sync**, because the server starts again from the three test patients. If they still do not load, run `./lab-init.sh` in its terminal and read **Since the last run** in what it prints. When that says `CHANGED`, open the new addresses. See **Find your addresses again**. |
| The Editor or App address stopped working | The same cause and the same fix as the row above. |
| You lost the addresses or the password | Run `./lab-init.sh --info` in the Heropa terminal. It prints them again. |
| The browser warns that the connection is not private | The lab is in reduced mode. Click **Advanced**, then **Proceed**. See **If the lab starts in reduced mode**. |
| The Editor shows a notice about reduced mode, or has no Guide, Build log or Output area | The lab could not get a trusted certificate. Use the pages listed under **If the lab starts in reduced mode**, and run `./lab-init.sh` again later. |
