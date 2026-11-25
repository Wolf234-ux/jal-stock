#!/usr/bin/env bash
# Forces every Android plugin to compile against SDK 36 (needed by newer
# AndroidX libraries). Safe to run more than once.
set -e
MARK="// jalstock-compileSdk-fix"
if [ -f android/build.gradle.kts ]; then
  F=android/build.gradle.kts
  grep -q "$MARK" "$F" || cat >> "$F" <<'KTS'

// jalstock-compileSdk-fix
subprojects {
    val forceSdk: Project.() -> Unit = {
        val ext = extensions.findByName("android")
        if (ext != null && name != "app") {
            ext.javaClass.methods.firstOrNull { it.name == "setCompileSdk" && it.parameterCount == 1 }
                ?.invoke(ext, 36)
        }
    }
    if (state.executed) forceSdk() else afterEvaluate { forceSdk() }
}
KTS
else
  F=android/build.gradle
  grep -q "$MARK" "$F" || cat >> "$F" <<'GRV'

// jalstock-compileSdk-fix
subprojects { p ->
    def forceSdk = {
        def a = p.extensions.findByName("android")
        if (a != null && p.name != "app") { a.compileSdkVersion(36) }
    }
    if (p.state.executed) { forceSdk() } else { p.afterEvaluate { forceSdk() } }
}
GRV
fi
# the app itself
for G in android/app/build.gradle.kts android/app/build.gradle; do
  [ -f "$G" ] && sed -i -E 's/compileSdk *= *flutter\.compileSdkVersion/compileSdk = 36/; s/compileSdk +flutter\.compileSdkVersion/compileSdk 36/' "$G"
done
echo "compileSdk 36 applied to $F"
