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
| **slack_updates** (pending)             | Sends slack notification when a new boshrelease are available. |
| **update_deployment**                   | When enabled it will create update jobs for each of your environments. This can be useful when you do not want a new tile or stemcell to apply when deploying. |
| **pin_versions** (Requires concouse v5) | Pins resources to provided version through a yaml config file. |
| **restart_on_failure** (For Logsearch)  | Restarts ingestor if no logs have been recieved in the last 15 min. |

## Environment Features

| name                                    |                                         |
|-----------------------------------------|-----------------------------------------|
| **allow_destroy**                       | When enabled it will add a destroy job to remove the boshrelease in the provided environment.  Recomended only for dev environments. |
| **backup**                              | `<opts>[daily, on_updates]` Performs bbr backup and upload it to S3. |
| **set_teams** (For Concourse)           | pending |
| **pin_versions** (Requires concouse v5) | Pins resources to provided version through a yaml config file. |
| **restart_on_failure** (For Logsearch)  | Restarts ingestor if no logs have been recieved in the last 15 min. |
| **check_cluster** (For Vault)           | Reads and writes a secret in vault. Fails when it can not perform the read.  |

