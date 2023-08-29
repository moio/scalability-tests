import {spawnSync} from 'child_process'
import {dirname, relative, join} from 'path'
import {cwd, env} from 'process'
import {fileURLToPath} from 'url'

export const ADMIN_PASSWORD = "adminadminadmin"

export function dir(dir){
    const desiredPath = join(dirname(dirname(dirname(fileURLToPath(import.meta.url)))), dir)
    const currentPath = cwd()
    const result = relative(currentPath, desiredPath)

    return result !== "" ? result : "."
}

export function isK3d() {
    return terraformDir().endsWith("k3d")
}

export function terraformDir(){
    const default_dir = dir(join("terraform", "main", "k3d"))
    return env.TERRAFORM_WORK_DIR ?? default_dir
}

export function terraformVar() {
    if (env.TERRAFORM_VAR_FILE) {
        return `-var-file=${env.TERRAFORM_VAR_FILE}`
    }
    return ""
}

/** wait for given number of milliseconds */
function msleep(ms) {
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms)
}

/**
 * Run shell command and return output if required.
 *
 * If `tries` is more than one, the command is executed until succeeds,
 * but no more than the given number times.
 * If `ignore` provided the stderr is captured and the command is repeated
 * only if the stderr contains the given text, otherwise we return immediately.
 *
 * @param ignore    Retry command only if the stderr includes text from `ignore`.
 *                  Not used if `tries` is not provided or 1.
 * @param tries     Maximum number of attempts to succeed the command without error.
 * @param wait      Number of seconds to wait between attempts.
 */
export function run(cmdline, options = {}) {
    console.log(`***Running command:\n ${cmdline}\n`)
    var tries = options.tries ?? 1
    var retryWaitSeconds = options.waitSecs ?? 1
    var ignoreText = options.ignore ?? ""
    var res
    while (tries > 0) {
        tries -= 1
        res = spawnSync(cmdline, [], {
            input: options.input,
            stdio: [options.input ? "pipe": "inherit",
                    options.collectingOutput ? "pipe" : "inherit",
                    // we need to capture stderr for checking `ignore` text
                    options.ignore ? "pipe" : "inherit"],
            shell: true
        })
        if (res.error){
            throw res.error
        }
        // because of ignore check, we capture the stderr
        // which is not duplicated, so just print it out now
        if (options.ignore) {
            console.error(res.stderr?.toString())
        }
        if (res.status === 0) {
            break
        }
        console.log("")
        if (tries === 0) {
            throw new Error(`Command returned status ${res.status}`)
        }
        if (options.ignore) {
            var ignoring = res.stderr?.toString().includes(ignoreText)
            if (ignoring) {
                console.log(`Ignoring because of: ${ignoreText}`)
            } else {
                throw new Error(`Command returned status ${res.status}`)
            }
        }
        console.error(`Waiting ${retryWaitSeconds} seconds before next try...`)
        msleep(retryWaitSeconds * 1000)
    }
    return res.stdout?.toString()
}

/** Quotes a string for Unix shell use */
export function q(s){
    if (!/[^%+,-.\/:=@_0-9A-Za-z]/.test(s)){
        return s
    }
    return `'` + s.replace(/'/g, `'"'`) + `'`
}

export function runCollectingOutput(cmdline) {
    return run(cmdline, {collectingOutput: true})
}

export function runCollectingJSONOutput(cmdline) {
    return JSON.parse(runCollectingOutput(cmdline))
}

export function sleep(s) {
    return new Promise(resolve => setTimeout(resolve, s*1000));
}

export function helm_install(name, chart, cluster, namespace, values) {
    const json = Object.entries(values).map(([k,v]) => `${k}=${JSON.stringify(v)}`).join(",")
    run(`helm --kubeconfig=${q(cluster["kubeconfig"])} --kube-context=${q(cluster["context"])} upgrade --install --namespace=${q(namespace)} ${q(name)} ${q(chart)} --create-namespace --set-json=${q(json)}`)
}
