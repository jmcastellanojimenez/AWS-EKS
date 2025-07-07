/**
 *
 * Vault
 *
 * This module creates secrets and retrieve secrets from Vault
 *
 * Necessary variable:
 *
 * eksCluster
 * Secret Name: name of the secret in vault
 * Secret Path: the location of the secret on vault
 * Generic Secret: information to save in the secret
 *
 */

import { EksStack } from "../../main";
import { GenericSecret } from "../../../.gen/providers/vault/generic-secret";
import { DataVaultGenericSecret } from "../../../.gen/providers/vault/data-vault-generic-secret";

interface vaultSecret {
  secretPath: string;
  genericSecret: string;
}

export class generateVaultSecret {
  private secret: GenericSecret;

  constructor(scope: EksStack, id: string, config: vaultSecret) {
    this.secret = new GenericSecret(scope, id, {
      dataJson: config.genericSecret,
      path: config.secretPath,
    });
  }

  public getGeneratedSecret(): GenericSecret {
    return this.secret;
  }
}

export class getVaultSecret {
  private secret: DataVaultGenericSecret;

  constructor(scope: EksStack, secretName: string, secretPath: string) {
    this.secret = new DataVaultGenericSecret(scope, `secret-${secretName}`, {
      path: secretPath,
    });
  }

  public getSecret(): DataVaultGenericSecret {
    return this.secret;
  }
}
