/**
 * 
 * Providers
 * 
 * This module defines the default providers for AWS and Vault
 * 
 */

import { S3Backend, Fn } from "cdktf";
import { EksStack } from "./main"

import { AwsProvider } from "../.gen/providers/aws/provider";
import { VaultProvider } from "../.gen/providers/vault/provider";
import { AwxProvider } from '../.gen/providers/awx/provider'

import { getVaultSecret } from "./modules/vault/vault"

export function setUpProvider(scope: EksStack, region: string, clusterName: string, account: string) {

  // Default AWS provider
  new AwsProvider(scope, "aws", {
    profile: process.env.AWS_PROFILE,
    region: region,
  });

  // S3 Backend - https://www.terraform.io/docs/backends/types/s3.html
  new S3Backend(scope, {
    bucket: `tf-bucket-${account}`,
    key: `eks-cluster-cdktf/${clusterName}.tfstate`,
    region: region,
    dynamodbTable: "tf-lock-table",
  });
}

// Vault Provider
export function setUpVaultProvider(scope: EksStack) {
  new VaultProvider(scope, "vault", {
    address: "https://vault.internal.epo.org",
    //address: "https://vaultlab.internal.epo.org",
    token: process.env.VAULT_TOKEN,
    skipTlsVerify: true
  })
}

export function awxProvider(scope: EksStack) {
  // Get AWX Credentials from vault
  //const secret = new getVaultSecret(scope, "awx-secret", "secret/fram/ansible-awx/web-administrator-credentials")
  const secret = new getVaultSecret(scope, "awx-secret", "secret/pequod/ansible-awx/web-administrator-credentials")
  const awxPassword = Fn.lookup(secret.getSecret().data, "password", "");

  // Define AWX provider
  new AwxProvider(scope, "awx-provider", {
    //hostname: "https://ansible-awx.platform-staging.internal.epo.org/",
    hostname: "https://ansible-awx.platform-staging.internal.epo.org/",
    username: "awxadmin",
    password: awxPassword
  });
}