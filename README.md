# Boshrelease-ta-deployment


Travel agent deployment project to deploy the following boshreleases:

* logsearch-boshrelease
* logsearch-for-cloudfoundry-boshrelease
* jumpbox-boshrelease
* os-conf-boshrelease
* bosh-vsphere-cpi-boshrelease
* prometheus-boshrelease
* postgres-boshrelease
* cf-routing-boshrelease
* bpm-boshrelease
* concourse-boshrelease
* garden-runc-boshrelease
* backup-and-restore-sdk-boshrelease
* vault-boshrelease
* vault-bbr-boshrelease
* consul-boshrelease

## Global features

| name                          |                                         |
|-----------------------------------------|-----------------------------------------|
| **slack_updates**                       | Sends slack notification when a deployment finishes. |
| **lock_environment**                   | Uses the concourse pool resource to claim/unclaim the job specific environment. |
| **pin_versions** (Requires concouse v5) | Pins resources to provided version through a yaml config file. |
| **restart_on_failure** (For Logsearch)  | Restarts ingestor if no logs have been recieved in the last 15 min. |
| **update_cloud_config** (For Bosh)      | Adds update cloud config jobs for all bosh environments. |

## Environment Features

| name                                    |                                         |
|-----------------------------------------|-----------------------------------------|
| **allow_destroy**                       | When enabled it will add a destroy job to remove the boshrelease in the provided environment.  Recomended only for dev environments. |
| **lock_environment**                    | Uses the concourse pool resource to claim/unclaim the current environment. (overrides lock_environment global feature) |
| **backup**                              | `<opts>[daily, on_demand, on_updates]` Performs bbr backup and upload it to S3. |
| **set_teams** (For Concourse)           | pending |
| **pin_versions** (Requires concouse v5) | Pins resources to provided version through a yaml config file. |
| **restart_on_failure** (For Logsearch)  | Restarts ingestor if no logs have been recieved in the last 15 min. |
| **check_cluster** (For Vault)           | Reads and writes a secret in vault. Fails when it can not perform the read.  |
| **create_policies** (For Vault)         | Create or update policies in vault. Policy name will match provided policy file name.  |

