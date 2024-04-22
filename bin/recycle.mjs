#!/usr/bin/env node
import {
    ADMIN_PASSWORD,
    dir,
    terraformDir,
    terraformVar,
    helm_install,
    q,
    run,
    runCollectingJSONOutput,
    runCollectingOutput,
    isK3d,
    retryOnError,
    getAppAddressesFor,
    importImage,
} from "./lib/common.mjs"
import {k6_run} from "./lib/k6.mjs";
import {install_rancher_monitoring} from "./lib/rancher_monitoring.mjs";

// Parameters
const RANCHER_IMAGE_TAG = `v2.7.9-debug-42864-5`
const ROUNDS = 40 // +1 for local + 1 for original downstream = 42 total cluster objects. 42 is the answer to life, the universe, and everything

for (let i = 0; i < ROUNDS; i++) {
    // recycle the downstream cluster
    run(`terraform -chdir=${q(terraformDir())} taint "module.cluster[1].k3d_cluster.cluster[0]"`)
    run(`terraform -chdir=${q(terraformDir())} taint "module.cluster[1].local_file.kubeconfig[0]"`)
    run(`terraform -chdir=${q(terraformDir())} apply -auto-approve ${q(terraformVar())}`)

    // register the downstream cluster
    const clusters = runCollectingJSONOutput(`terraform -chdir=${q(terraformDir())} output -json`)["clusters"]["value"]

    const suffix = Math.random().toString(36).substring(7)
    const importedClusters = Object.entries(clusters).filter(([k,v]) => k.startsWith("downstream")).map(([k,v]) => [k + suffix,v])
    const importedClusterNames = importedClusters.map(([name, cluster]) => name).join(",")

    importImage(`rancher/rancher-agent:${RANCHER_IMAGE_TAG}`, ...importedClusters.map(([name, cluster]) => cluster))

    const upstream = clusters["upstream"]
    const upstreamAddresses = getAppAddressesFor(upstream)
    const rancherURL = upstreamAddresses.localNetwork.httpsURL
    const rancherClusterNetworkURL = upstreamAddresses.clusterNetwork.httpsURL
    const kuf = `--kubeconfig=${upstream["kubeconfig"]}`
    const cuf = `--context=${upstream["context"]}`

    const tester = clusters["tester"]
    k6_run(tester, { BASE_URL: rancherClusterNetworkURL, PASSWORD: ADMIN_PASSWORD, IMPORTED_CLUSTER_NAMES: importedClusterNames}, {}, "k6/quick_import.js")

    for (const [name, cluster] of importedClusters) {
        const clusterId = await retryOnError(() =>
            runCollectingJSONOutput(`kubectl get -n fleet-default clusters.provisioning.cattle.io ${q(name)} -o json ${q(kuf)} ${q(cuf)}`)["status"]["clusterName"]
        )
        const token = runCollectingJSONOutput(`kubectl get -n ${q(clusterId)} clusterregistrationtoken.management.cattle.io default-token -o json ${q(kuf)} ${q(cuf)}`)["status"]["token"]

        const url = `${rancherURL}/v3/import/${token}_${clusterId}.yaml`
        const yaml = runCollectingOutput(`curl --insecure -fL ${q(url)}`)
        run(`kubectl apply -f - --kubeconfig=${q(cluster["kubeconfig"])} --context=${q(cluster["context"])}`, {input: yaml})

        await retryOnError(function () {
            run(`kubectl wait clusters.management.cattle.io ${clusterId} --for condition=ready=true --timeout=15m ${q(kuf)} ${q(cuf)}`)
            run(`kubectl wait cluster.fleet.cattle.io ${name} --namespace fleet-default --for condition=ready=true --timeout=15m ${q(kuf)} ${q(cuf)}`)
        })
    }
}
