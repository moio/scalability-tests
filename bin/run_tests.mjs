#!/usr/bin/env node
import {
    ADMIN_PASSWORD,
    dir,
    terraformDir,
    helm_install,
    q,
    runCollectingJSONOutput, runCollectingOutput,
} from "./lib/common.mjs"
import {k6_run} from "./lib/k6.mjs"


// Parameters
const ROLE_COUNT = 10
const USER_COUNT = 1000

// Refresh k6 files on the upstream cluster
const clusters = runCollectingJSONOutput(`terraform -chdir=${terraformDir()} output -json`)["clusters"]["value"]
const upstream = clusters["upstream"]
helm_install("k6-files", dir("charts/k6-files"), upstream, "tester", {})

// Create config maps
const commit = runCollectingOutput("git rev-parse --short HEAD").trim()
const downstreams = Object.entries(clusters).filter(([k,v]) => k.startsWith("downstream"))


// Output access details
console.log("*** ACCESS DETAILS")
console.log()

console.log(`*** UPSTREAM CLUSTER`)
if (upstream["public_name"]) {
    console.log(`    Rancher UI: https://${upstream["public_name"]} (admin/${ADMIN_PASSWORD})`)
}
else {
    console.log(`    Rancher UI: https://${upstream["local_name"]}:${upstream["local_https_port"]} (admin/${ADMIN_PASSWORD})`)
}
console.log(`    Kubernetes API:`)
console.log(`export KUBECONFIG=${q(upstream["kubeconfig"])}`)
console.log(`kubectl config use-context ${q(upstream["context"])}`)
for (const [node, command] of Object.entries(upstream["node_access_commands"])) {
    console.log(`    Node ${node}: ${q(command)}`)
}
console.log()

for (const [name, downstream] of downstreams) {
    console.log(`*** ${name.toUpperCase()} CLUSTER`)
    console.log(`    Kubernetes API:`)
    console.log(`export KUBECONFIG=${q(downstream["kubeconfig"])}`)
    console.log(`kubectl config use-context ${q(downstream["context"])}`)
    for (const [node, command] of Object.entries(downstream["node_access_commands"])) {
        console.log(`    Node ${node}: ${q(command)}`)
    }
    console.log()
}
console.log()
