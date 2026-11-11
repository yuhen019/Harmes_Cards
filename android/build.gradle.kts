allprojects {
    repositories {
        // 国内镜像优先，直连兜底（与 settings.gradle.kts 保持一致）
        maven("https://maven.aliyun.com/repository/google")
        maven("https://maven.aliyun.com/repository/public")
        maven("https://mirrors.cloud.tencent.com/nexus/repository/maven-public/")
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// 第三方插件（file_picker 8.x 等）自己写死 compileSdk 34，而 flutter_plugin_android_lifecycle
// 要求依赖方用 36 编译，混在一起会直接 AAR metadata 校验失败。
// 这里在每个模块评估完成后，统一把 compileSdk 抬到 36（只影响编译期，不动 minSdk / targetSdk）。
//
// 用 gradle.afterProject 而不是 subprojects{ afterEvaluate{} }：
// 模板里更靠前的 evaluationDependsOn(":app") 会让 :app 在注册回调前就被评估，
// 再调 afterEvaluate 会直接抛 "project is already evaluated"。
//
// 用反射设置而不是直接引用 AGP 的类：根工程脚本编译期没有 AGP 依赖，
// 且新旧 DSL（android.newDsl）的扩展类名不同，反射两边都能命中。
gradle.afterProject {
    val androidExt = extensions.findByName("android") ?: return@afterProject
    val target = 36
    val setter = androidExt.javaClass.methods.firstOrNull {
        it.name == "setCompileSdk" && it.parameterCount == 1
    }
    if (setter != null) {
        setter.invoke(androidExt, target)
    } else {
        androidExt.javaClass.methods.firstOrNull {
            it.name == "compileSdkVersion" && it.parameterCount == 1
        }?.invoke(androidExt, target)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
