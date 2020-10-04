#!/usr/bin/env bash

set -e

#####
# main
##################
main() {
  check_environment $@
  create_filestore
  create_config_values
}

#####
# check_environment
##################
check_environment() {
  ## Check for Azure CLI command
  command -v gcloud > /dev/null || \
    { echo "[ERROR]: 'az' command not not found" 1>&2; exit 1; }

  if [[ -z "${MY_FS_NAME}" ]]; then
    if (( $# < 1 )); then
      printf "[ERROR]: Need at least one parameter or define 'MY_FS_NAME'\n\n" 1>&2
      printf "Usage:\n\t$0 <container-name>\n\tMY_FS_NAME=<filestore-name> $0\n" 1>&2
      exit 1
    fi
  fi

  MY_PROJECT=${MY_PROJECT:-$(gcloud config get-value project)}
  MY_ZONE=${MY_ZONE:-"us-central1-b"}
  MY_FS_TIER=${MY_FS_TIER:-"STANDARD"}
  MY_FS_CAPACITY=${MY_FS_CAPACITY:-"1TB"}
  MY_FS_SHARE_NAME=${MY_FS_SHARE_NAME:-"volumes"}
  MY_NETWORK_NAME=${MY_NETWORK_NAME:-"default"}
  MY_FS_NAME=${MY_FS_NAME:-$1}
  CREATE_ENV_VALUES=${CREATE_ENV_VALUES:-"true"}

}

#####
# create_filestore
##################
create_filestore() {
  if ! gcloud filestore instances list | grep -q ${MY_FS_NAME}; then
    gcloud filestore instances create ${MY_FS_NAME} \
      --project=${MY_PROJECT} \
      --zone=${MY_ZONE} \
      --tier=${MY_FS_TIER} \
      --file-share=name="${MY_FS_SHARE_NAME}",capacity=${MY_FS_CAPACITY} \
      --network=name="${MY_NETWORK_NAME}"
  fi
}

#####
# create_config_values
##################
create_config_values() {
  ## TODO: Verify Server Exists

  ## Create Minio  env file and Helm Chart secret files
  if [[ "${CREATE_ENV_VALUES}" =~ true|(y)es ]]; then
    echo "[INFO]: Creating 'env.sh' file"
    SERVER_ADDRESS=$(gcloud filestore instances describe ${MY_FS_NAME} \
      --project=${MY_PROJECT} \
      --zone=${MY_ZONE} \
      --format="value(networks.ipAddresses[0])"
    )
    SERVER_SHARE=$(gcloud filestore instances describe ${MY_FS_NAME} \
      --project=${MY_PROJECT} \
      --zone=${MY_ZONE} \
      --format="value(fileShares[0].name)"
    )

    cat <<-EOF > ../env.sh
export NFS_PATH="${SERVER_SHARE}"
export NFS_SERVER="${SERVER_ADDRESS}"
EOF
  fi
}

main $@
