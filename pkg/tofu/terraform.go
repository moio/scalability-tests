/*
Copyright © 2024 SUSE LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package tofu

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/hashicorp/terraform-exec/tfexec"
)

type ClusterAddress struct {
	HTTPPort  uint   `json:"http_port"`
	HTTPSPort uint   `json:"https_port"`
	Name      string `json:"name"`
}

type ClusterAppAddresses struct {
	Private ClusterAddress `json:"private"`
	Public  ClusterAddress `json:"public"`
	Tunnel  ClusterAddress `json:"tunnel"`
}

type Cluster struct {
	AppAddresses            ClusterAppAddresses `json:"app_addresses"`
	Context                 string              `json:"context"`
	IngressClassName        string              `json:"ingress_class_name"`
	Kubeconfig              string              `json:"kubeconfig"`
	NodeAccessCommands      map[string]string   `json:"node_access_commands"`
	PrivateKubernetesAPIURL string              `json:"private_kubernetes_api_url"`
}

type Tofu struct {
	tf      *tfexec.Terraform
	dir     string
	Threads int
}

const DefaultThreads = 10

func (t *Tofu) Init(dir string, verbose bool) error {
	t.dir = dir

	tfBinary, err := exec.LookPath("tofu")
	if err != nil {
		return fmt.Errorf("error: tofu init: %w", err)
	}

	if t.Threads == 0 {
		t.Threads = DefaultThreads
	}
	t.tf, err = tfexec.NewTerraform(dir, tfBinary)
	if err != nil {
		return fmt.Errorf("error: tofu Init: %w", err)
	}

	if verbose {
		t.tf.SetStdout(os.Stdout)
	}

	if err = t.tf.Init(context.Background(), tfexec.Upgrade(true)); err != nil {
		return fmt.Errorf("error: tofu Init: %w", err)
	}

	return nil
}

func (t *Tofu) Destroy(path string) error {
	if len(path) > 0 {
		if err := t.tf.Destroy(context.Background(),
			tfexec.VarFile(path), tfexec.Parallelism(t.Threads)); err != nil {
			return fmt.Errorf("error: tofu Destroy: %w", err)
		}
	}
	if err := t.tf.Destroy(context.Background()); err != nil {
		return fmt.Errorf("error: tofu Destroy: %w", err)
	}

	return nil
}

func (t *Tofu) Apply(path string) error {
	if len(path) > 0 {
		if err := t.tf.Apply(context.Background(),
			tfexec.VarFile(path), tfexec.Parallelism(t.Threads)); err != nil {
			return fmt.Errorf("error: tofu Apply: %w", err)
		}
	}
	if err := t.tf.Apply(context.Background()); err != nil {
		return fmt.Errorf("error: tofu Apply: %w", err)
	}

	return nil
}

func (t *Tofu) OutputClustersJson() (string, error) {
	tfOutput, err := t.tf.Output(context.Background())
	if err != nil {
		return "", fmt.Errorf("error: tofu OutputClustersJson: %w", err)
	}

	if clusters, ok := tfOutput["clusters"]; ok {
		return string(clusters.Value), nil
	}

	return "", fmt.Errorf("error: tofu OutputClustersJson: no cluster data")
}

func (t *Tofu) OutputClusters() (map[string]Cluster, error) {
	tfOutput, err := t.tf.Output(context.Background())
	if err != nil {
		return nil, fmt.Errorf("error: tofu OutputClusters: %w", err)
	}

	clusters := map[string]Cluster{}
	if err := json.Unmarshal(tfOutput["clusters"].Value, &clusters); err != nil {
		return nil, fmt.Errorf("error: tofu OutputClusters: %w", err)
	}

	return clusters, nil

}

// Version queries Tofu version and the provider list.
// It returns the version as a string, the provider list as a map of strings
// and any error encountered.
func (t *Tofu) Version() (version string, providers map[string]string, err error) {
	tfVer, tfProv, err := t.tf.Version(context.Background(), false)
	if err != nil {
		err = fmt.Errorf("error: tofu GetVersion: %w", err)
		return
	}

	version = tfVer.String()
	providers = make(map[string]string)
	for prov, ver := range tfProv {
		providers[prov] = ver.String()
	}

	return
}

// IsK3d determines if the current backend is k3d
func (t *Tofu) IsK3d() bool {
	_, f := filepath.Split(t.dir)
	return f == "k3d"
}
