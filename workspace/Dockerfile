# The learner workspace for the Kotlin FHIR Engine codelab.
#
# It holds a JDK, the codelab checkout, a warm Gradle cache and code-server,
# which is VS Code served to a browser. The web target needs no Android SDK
# and no Android Studio.

FROM eclipse-temurin:21-jdk

ARG CODE_SERVER_VERSION=4.145.2
ARG CODELAB_REPO=https://github.com/ohs-foundation/kotlin-fhir-engine.git
# The commit the solution files in solutions/ were written against. Change
# both together.
ARG CODELAB_REF=697412d04157980fc24eb3fbb2e8e5c479b0f0ee

# libatomic1 is needed by the Node.js binary that the Kotlin Gradle plugin
# downloads. Without it the Wasm build stops with exit code 127.
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates curl git inotify-tools less libatomic1 nano vim \
 && curl -fsSL -o /tmp/code-server.deb \
      "https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server_${CODE_SERVER_VERSION}_amd64.deb" \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y /tmp/code-server.deb \
 && rm -rf /tmp/code-server.deb /var/lib/apt/lists/*

# One unprivileged account with uid 1000. The base image may already use that
# uid for an account named ubuntu, which is removed first.
RUN (id ubuntu >/dev/null 2>&1 && userdel -r ubuntu || true) \
 && useradd --create-home --uid 1000 --shell /bin/bash learner \
 && chmod 755 /home/learner

COPY --chown=learner:learner solutions /opt/codelab/solutions

USER learner
WORKDIR /home/learner
ENV CODELAB_DIR=/home/learner/kotlin-fhir-engine/codelabs
ENV CODELAB_SRC=shared/src/commonMain/kotlin/dev/ohs/fhir/codelab

# A sparse checkout of the pinned commit, the same shape the codelab asks for.
#
# The lab then changes three things in the starter code and commits them, so
# the checkout is clean and step reset returns to it.
#
#   1. The web entry point reads the FHIR server address from the page it runs
#      in. The published one says localhost, which in a learner's browser is
#      their own computer and not this VM.
#   2. The files a learner edits get numbered comments under their imports.
#      The published starter marks each place for code that way but has none
#      for imports, because Android Studio adds those.
#   3. ForegroundSyncLauncher prints the error it catches, so a failed sync
#      leaves a line in the Output tab.
#
# It also turns on incremental Wasm builds in gradle.properties. A build after
# a small edit then takes about a third of the time. Kotlin marks the switch
# as experimental, so remove that line if a build ever gives a stale app.
RUN git init -q -b codelab kotlin-fhir-engine \
 && cd kotlin-fhir-engine \
 && git remote add origin "$CODELAB_REPO" \
 && git sparse-checkout set codelabs gradle \
 && git fetch -q --depth 1 --filter=blob:none origin "$CODELAB_REF" \
 && git reset -q --hard FETCH_HEAD \
 && printf '.vscode/\nkotlin-js-store/\n' >> .git/info/exclude \
 && cd codelabs \
 && cp /opt/codelab/solutions/starter/Main.kt shared/src/wasmJsMain/kotlin/dev/ohs/fhir/codelab/Main.kt
RUN cd "$CODELAB_DIR" \
 && for f in /opt/codelab/solutions/starter/*.kt; do \
      [ "$(basename "$f")" = Main.kt ] || cp "$f" "$CODELAB_SRC/"; \
    done \
 && printf '\n# Added by the lab. Rebuilds only what an edit changed.\nkotlin.incremental.wasm=true\n' >> gradle.properties \
 && test -n "$(git status --porcelain)" \
 && git -c user.name="Codelab lab" -c user.email="lab@localhost" \
      commit -q -a -m "Adapt the starter for the lab"

# Warm the Gradle cache. The finished codelab is built first so everything it
# pulls in is already downloaded. The starter is built last so the App tab
# shows it as soon as the lab starts.
RUN cd "$CODELAB_DIR" \
 && cp /opt/codelab/solutions/step-7/*.kt "$CODELAB_SRC/" \
 && ./gradlew --no-daemon --console=plain -q :shared:wasmJsBrowserDevelopmentExecutableDistribution \
 && git checkout -q -- . \
 && ./gradlew --no-daemon --console=plain -q :shared:wasmJsBrowserDevelopmentExecutableDistribution \
 && { test -z "$(git status --porcelain)" || { git status --porcelain; exit 1; }; } \
 && test -f shared/build/dist/wasmJs/developmentExecutable/index.html

# Kotlin colouring for the editor. It is a grammar only, with no language
# server, so it costs no memory.
RUN code-server --install-extension mathiasfrohlich.Kotlin

COPY --chown=learner:learner ide/settings.json /home/learner/.local/share/code-server/User/settings.json
COPY --chown=learner:learner ide/bashrc        /home/learner/.bashrc.codelab
RUN echo '. ~/.bashrc.codelab' >> /home/learner/.bashrc

# The guide extension opens the course manual beside the code. The JDK's jar
# tool makes the VSIX package, which is a plain zip file. The package is kept
# so the entry point can install it into a volume made by an older image.
USER root
COPY ide/codelab-guide /opt/codelab/guide-ext
RUN jar --create --no-manifest --file /opt/codelab/codelab-guide.vsix -C /opt/codelab/guide-ext . \
 && chmod 644 /opt/codelab/codelab-guide.vsix \
 && mkdir -p /opt/codelab/guide
USER learner
RUN code-server --install-extension /opt/codelab/codelab-guide.vsix

COPY --chmod=755 bin/ /usr/local/bin/

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/workspace-entrypoint"]
