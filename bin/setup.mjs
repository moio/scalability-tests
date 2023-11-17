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
} from "./lib/common.mjs"
import {k6_run} from "./lib/k6.mjs";
import {install_rancher_monitoring} from "./lib/rancher_monitoring.mjs";

// Parameters
const RANCHER_VERSION = "2.7.6"
const RANCHER_CHART = `https://releases.rancher.com/server-charts/latest/rancher-${RANCHER_VERSION}.tgz`
const RANCHER_IMAGE_TAG = `v${RANCHER_VERSION}`
const CERT_MANAGER_CHART = "https://charts.jetstack.io/charts/cert-manager-v1.8.0.tgz"
const GRAFANA_CHART = "https://github.com/grafana/helm-charts/releases/download/grafana-6.56.5/grafana-6.56.5.tgz"

// Step 1: Terraform
run(`terraform -chdir=${q(terraformDir())} init -upgrade`)
run(`terraform -chdir=${q(terraformDir())} apply -auto-approve ${q(terraformVar())}`)
const clusters = runCollectingJSONOutput(`terraform -chdir=${q(terraformDir())} output -json`)["clusters"]["value"]



// Step 2: Helm charts

// upstream cluster
const upstream = clusters["upstream"]
helm_install("cert-manager", CERT_MANAGER_CHART, upstream, "cert-manager", {installCRDs: true})

const BOOTSTRAP_PASSWORD = "admin"
const privateUpstreamName = upstream["private_name"]
const privateRancherUrl = `https://${privateUpstreamName}`
helm_install("rancher", RANCHER_CHART, upstream, "cattle-system", {
    bootstrapPassword: BOOTSTRAP_PASSWORD,
    hostname: privateUpstreamName,
    replicas: isK3d() ? 1 : 3,
    rancherImageTag: RANCHER_IMAGE_TAG,
    extraEnv: [{
        name: "CATTLE_SERVER_URL",
        value: privateRancherUrl
    },
    {
        name: "CATTLE_PROMETHEUS_METRICS",
        value: "true"
    },
    {
        name: "CATTLE_DEV_MODE",
        value: "true"
    }],
    livenessProbe: {
        initialDelaySeconds: 30,
        periodSeconds: 3600
    }
})

const localUpstreamName = upstream["local_name"]
const publicUpstreamName = upstream["public_name"]
helm_install("rancher-ingress", dir("charts/rancher-ingress"), upstream, "default", {
    sans: [localUpstreamName, privateUpstreamName, publicUpstreamName].filter(x => x),
})

const monitoringRestrictions = {
    nodeSelector: {monitoring: "true"},
    tolerations: [{key: "monitoring", operator: "Exists", effect: "NoSchedule"}],
}

install_rancher_monitoring(upstream, isK3d() ? {} : monitoringRestrictions)

helm_install("cgroups-exporter", dir("charts/cgroups-exporter"), upstream, "cattle-monitoring-system", {})

const kuf = `--kubeconfig=${upstream["kubeconfig"]}`
const cuf = `--context=${upstream["context"]}`
run(`kubectl wait deployment/rancher --namespace cattle-system --for condition=Available=true --timeout=1h ${q(kuf)} ${q(cuf)}`)


// Step 3: Import downstream clusters
const localRancherUrl = `https://${localUpstreamName}:${upstream["local_https_port"]}`
const importedClusters = Object.entries(clusters).filter(([k,v]) => k.startsWith("downstream"))
const importedClusterNames = importedClusters.map(([name, cluster]) => name).join(",")
helm_install("k6-files", dir("charts/k6-files"), upstream, "tester", {})
k6_run(upstream, { BASE_URL: privateRancherUrl, BOOTSTRAP_PASSWORD: BOOTSTRAP_PASSWORD, PASSWORD: ADMIN_PASSWORD, IMPORTED_CLUSTER_NAMES: importedClusterNames}, {}, "k6/rancher_setup.js")

for (const [name, cluster] of importedClusters) {
    const clusterId = await retryOnError(() =>
        runCollectingJSONOutput(`kubectl get -n fleet-default cluster ${q(name)} -o json ${q(kuf)} ${q(cuf)}`)["status"]["clusterName"]
    )
    const token = runCollectingJSONOutput(`kubectl get -n ${q(clusterId)} clusterregistrationtoken.management.cattle.io default-token -o json ${q(kuf)} ${q(cuf)}`)["status"]["token"]

    const url = `${localRancherUrl}/v3/import/${token}_${clusterId}.yaml`
    const yaml = runCollectingOutput(`curl --insecure -fL ${q(url)}`)
    run(`kubectl apply -f - --kubeconfig=${q(cluster["kubeconfig"])} --context=${q(cluster["context"])}`, {input: yaml})
}

run(`kubectl wait clusters.management.cattle.io --all --for condition=ready=true --timeout=1h ${q(kuf)} ${q(cuf)}`)

if (importedClusters.length > 0) {
    run(`kubectl wait cluster.fleet.cattle.io --all --namespace fleet-default --for condition=ready=true --timeout=1h ${q(kuf)} ${q(cuf)}`)
}
