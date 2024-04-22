import {getCookies, login, logout} from "./rancher_utils.js";
import { check } from 'k6'
import http from 'k6/http'

export const options = {
    insecureSkipTLSVerify: true,
}

export default function main() {
    const baseUrl = __ENV.BASE_URL
    const password = __ENV.PASSWORD
    const importedClusterNames = __ENV.IMPORTED_CLUSTER_NAMES.split(",")

    const cookies = getCookies(baseUrl)

    login(baseUrl, cookies, "admin", password)

    for (const i in importedClusterNames) {
        createImportedCluster(baseUrl, cookies, importedClusterNames[i])
    }

    logout(baseUrl, cookies)
}

export function createImportedCluster(baseUrl, cookies, name) {
    const response = http.post(
        `${baseUrl}/v1/provisioning.cattle.io.clusters`,
        JSON.stringify({
            "type": "provisioning.cattle.io.cluster",
            "metadata": {"namespace": "fleet-default", "name": name},
            "spec": {}
        }),
        {
            headers: {
                accept: 'application/json',
                'content-type': 'application/json',
            },
            cookies: cookies,
        }
    )

    check(response, {
        'creating an imported cluster works': (r) => r.status === 201 || r.status === 409,
    })
    if (response.status === 409) {
        console.warn(`cluster ${name} already exists`)
    }
}
