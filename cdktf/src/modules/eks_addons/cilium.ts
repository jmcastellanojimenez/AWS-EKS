/**
 *
 * Cilium
 *
 * This patchs the aws-nodes and install Cilium through helm chart
 *
 * Necessary variable:
 *
 * eksCluster this is the eks resource
 * eksNodegroup this is the nodegroup resource
 *
 */

import { Fn } from "cdktf";
import { EksStack } from "../../main";
import { EksCluster } from "../../../.gen/modules/eks_cluster";
import { EksNodegroup } from "../../../.gen/modules/eks_nodegroup";
import { DataAwsEksClusterAuth } from "../../../.gen/providers/aws/data-aws-eks-cluster-auth";
import { HelmProvider } from "../../../.gen/providers/helm/provider";
import { Release } from "../../../.gen/providers/helm/release";
import { generateVaultSecret } from "../../modules/vault/vault";

import { LocalProvider } from "../../../.gen/providers/local/provider";
import { SensitiveFile } from "../../../.gen/providers/local/sensitive-file";
import { NullProvider } from "../../../.gen/providers/null/provider";
import { Resource } from "../../../.gen/providers/null/resource";

import * as path from "path";
import * as fs from "fs";

export class eksCiliumAddon {
  private helmRelease: Release;

  constructor(
    scope: EksStack,
    eksCluster: EksCluster,
    eksNodegroup: EksNodegroup,
    clusterName: string,
  ) {
    // Obtain the cluster authentication token
    const clusterAuth = new DataAwsEksClusterAuth(scope, "cluster-data-auth", {
      name: eksCluster.clusterNameOutput,
    });

    // Set up local provider
    new LocalProvider(scope, "local-provider");

    // Set up the kubeconfig
    const kubeconfig = new SensitiveFile(scope, "kubeconfig", {
      content: Fn.templatefile(
        path.join(
          __dirname,
          "../../../../src/modules/eks_addons/files/kubeconfig.tpl",
        ),
        {
          cluster_name: eksCluster.clusterNameOutput,
          clusterca: eksCluster.clusterCertificateAuthorityDataOutput,
          endpoint: eksCluster.clusterEndpointOutput,
          token: clusterAuth.token,
        },
      ),
      filename: `./kubeconfig-${eksCluster.clusterNameOutput}`,
    });

    // Set up the null provider
    new NullProvider(scope, "null-provider");

    // Patch aws-node to allow cilium installation
    const patchAwsNode = new Resource(scope, "patch-aws-node", {
      provisioners: [
        {
          type: "local-exec",
          command: `kubectl -n kube-system patch daemonset aws-node --type='strategic' -p='{"spec":{"template":{"spec":{"nodeSelector":{"io.cilium/aws-node-enabled":"true"}}}}}' --kubeconfig=${kubeconfig.filename}`,
          environment: {
            KUBECONFIG: kubeconfig.filename,
          },
        },
      ],
      dependsOn: [eksCluster, eksNodegroup],
    });

    // Set up helm provider
    const helmEksProvider = new HelmProvider(scope, "helm-provider", {
      alias: "eks",
      kubernetes: {
        host: eksCluster.clusterEndpointOutput,
        clusterCaCertificate: Fn.base64decode(
          eksCluster.clusterCertificateAuthorityDataOutput,
        ),
        token: clusterAuth.token,
      },
    });

    const ciliumValuesYaml = fs.readFileSync(
      path.resolve(__dirname, "../../../../src/modules/eks_addons/files/cilium-values.yaml"),
      "utf8",
    );

    // Install cilium as a helm release
    this.helmRelease = new Release(scope, "cilium", {
      provider: helmEksProvider,
      name: "cilium",
      namespace: "kube-system",
      repository: "https://helm.cilium.io/",
      chart: "cilium",
      version: "1.16.1",
      values: [ciliumValuesYaml],
      set: [
        {
          name: "eni.enabled",
          value: "false",
        },
        {
          name: "k8sServiceHost",
          value: Fn.replace(eksCluster.clusterEndpointOutput, "https://", ""),
        },
        {
          name: "k8sServicePort",
          value: "443",
        },
      ],
      dependsOn: [patchAwsNode],
    });

    const dataJson = Fn.jsonencode({ kubeconfig: kubeconfig.content });

    // Save kubeconfig on vault
    new generateVaultSecret(scope, `kubeconfig-${clusterName}`, {
      secretPath: `secret/${clusterName}/kube-system/kubeconfig`,
      genericSecret: dataJson,
    });
  }

  public getHelmRelease(): Release {
    return this.helmRelease;
  }
}
