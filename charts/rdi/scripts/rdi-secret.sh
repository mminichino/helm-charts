#!/bin/bash

KUBECTL_COMMAND="kubectl"
RDI_NAMESPACE="rdi"

declare -a SECRET_NAMES_LIST=(
    source-db
    source-db-ssl
    target-db
    target-db-ssl
)

declare -A SOURCE_DB_SECRET_KEYS
SOURCE_DB_SECRET_KEYS[SOURCE_DB_USERNAME]=SOURCE_DB_USERNAME
SOURCE_DB_SECRET_KEYS[SOURCE_DB_PASSWORD]=SOURCE_DB_PASSWORD
SOURCE_DB_SECRET_KEYS[SOURCE_DB_KEY_PASSWORD]=SOURCE_DB_KEY_PASSWORD

declare -A TARGET_DB_SECRET_KEYS
TARGET_DB_SECRET_KEYS[TARGET_DB_USERNAME]=TARGET_DB_USERNAME
TARGET_DB_SECRET_KEYS[TARGET_DB_PASSWORD]=TARGET_DB_PASSWORD
TARGET_DB_SECRET_KEYS[TARGET_DB_KEY_PASSWORD]=TARGET_DB_KEY_PASSWORD

declare -A SOURCE_DB_SSL_SECRET_KEYS
SOURCE_DB_SSL_SECRET_KEYS[SOURCE_DB_CACERT]=ca.crt
SOURCE_DB_SSL_SECRET_KEYS[SOURCE_DB_CERT]=client.crt
SOURCE_DB_SSL_SECRET_KEYS[SOURCE_DB_KEY]=client.key

declare -A TARGET_DB_SSL_SECRET_KEYS
TARGET_DB_SSL_SECRET_KEYS[TARGET_DB_CACERT]=ca.crt
TARGET_DB_SSL_SECRET_KEYS[TARGET_DB_CERT]=client.crt
TARGET_DB_SSL_SECRET_KEYS[TARGET_DB_KEY]=client.key

declare -A SECRET_NAMES
SECRET_NAMES[SOURCE_DB_USERNAME]=source-db
SECRET_NAMES[SOURCE_DB_PASSWORD]=source-db
SECRET_NAMES[SOURCE_DB_KEY_PASSWORD]=source-db
SECRET_NAMES[SOURCE_DB_CACERT]=source-db
SECRET_NAMES[SOURCE_DB_CERT]=source-db
SECRET_NAMES[SOURCE_DB_KEY]=source-db
SECRET_NAMES[TARGET_DB_USERNAME]=target-db
SECRET_NAMES[TARGET_DB_PASSWORD]=target-db
SECRET_NAMES[TARGET_DB_KEY_PASSWORD]=target-db
SECRET_NAMES[TARGET_DB_CACERT]=target-db
SECRET_NAMES[TARGET_DB_CERT]=target-db
SECRET_NAMES[TARGET_DB_KEY]=target-db

declare -A SECRET_SSL_NAMES
SECRET_SSL_NAMES[SOURCE_DB_CACERT]=source-db-ssl
SECRET_SSL_NAMES[SOURCE_DB_CERT]=source-db-ssl
SECRET_SSL_NAMES[SOURCE_DB_KEY]=source-db-ssl
SECRET_SSL_NAMES[TARGET_DB_CACERT]=target-db-ssl
SECRET_SSL_NAMES[TARGET_DB_CERT]=target-db-ssl
SECRET_SSL_NAMES[TARGET_DB_KEY]=target-db-ssl

declare -A SECRET_SSL_KEYS
SECRET_SSL_KEYS[SOURCE_DB_CACERT]=ca.crt
SECRET_SSL_KEYS[SOURCE_DB_CERT]=client.crt
SECRET_SSL_KEYS[SOURCE_DB_KEY]=client.key
SECRET_SSL_KEYS[TARGET_DB_CACERT]=ca.crt
SECRET_SSL_KEYS[TARGET_DB_CERT]=client.crt
SECRET_SSL_KEYS[TARGET_DB_KEY]=client.key

declare -A PREDEFINED_SECRET_SSL_PATHS
PREDEFINED_SECRET_SSL_PATHS[SOURCE_DB_CACERT]="/etc/certificates/source_db/ca.crt"
PREDEFINED_SECRET_SSL_PATHS[SOURCE_DB_CERT]="/etc/certificates/source_db/client.crt"
PREDEFINED_SECRET_SSL_PATHS[SOURCE_DB_KEY]="/etc/certificates/source_db/client.key"
PREDEFINED_SECRET_SSL_PATHS[TARGET_DB_CACERT]="/etc/certificates/target_db/ca.crt"
PREDEFINED_SECRET_SSL_PATHS[TARGET_DB_CERT]="/etc/certificates/target_db/client.crt"
PREDEFINED_SECRET_SSL_PATHS[TARGET_DB_KEY]="/etc/certificates/target_db/client.key"

LIST_COMMAND="list"
GET_COMMAND="get"
SET_COMMAND="set"
DELETE_COMMAND="delete"

SCRIPT_DIR=(`dirname $0`)

SECRET_KEY=""
SECRET_VALUE=""
SECRET_NAME=""
SECRET_SSL_NAME=""
SECRET_SSL_KEY=""
SECRET_SSL_PATH=""
DRY_RUN="no"
COMMAND=$1

print_help() {
    echo "Usage:    $0 <COMMAND> <secret-key> [<secret-value>] [--namespace <namespace>]"
    echo ""
    echo "Examples: $0 list"
    echo "          $0 get SOURCE_DB_USERNAME"
    echo "          $0 set SOURCE_DB_USERNAME some_username"
    echo "          $0 set SOURCE_DB_USERNAME \"\""
    echo "          $0 delete SOURCE_DB_USERNAME"
    echo "          $0 SOURCE_DB_CACERT \"/path/to/ca/cert\""
    echo ""
    echo "Commands:"
    echo "  list               Prints all secrets to the console."
    echo "  get                Prints the value of the specified secret to the console."
    echo "  set                Creates or updates the specified secret."
    echo "  delete             Deletes the specified secret."
    echo "  -h, --help         Display this help message."
}

list_secrets() {
    local secret_name=$1
    local -n expected_secret_keys=$2

    local secrets_yaml=`$KUBECTL_COMMAND get secrets $secret_name --namespace=$RDI_NAMESPACE -o yaml 2>/dev/null`

    for secret_key in "${!expected_secret_keys[@]}"
    do
        local target_secret_key=${expected_secret_keys[$secret_key]}
        local secret_key_value=$(echo "$secrets_yaml" | grep "$target_secret_key: ")
        if [ -z "$secret_key_value" ]; then
            continue
        fi

        local secret_value=$(echo "$secret_key_value" | awk '{print $2}' | base64 --decode 2>/dev/null)
        echo "$secret_key: $secret_value"
    done
}

list() {
    for secret_name in "${SECRET_NAMES_LIST[@]}"
    do
        case $secret_name in
            source-db)
                list_secrets $secret_name SOURCE_DB_SECRET_KEYS
                ;;
            source-db-ssl)
                list_secrets $secret_name SOURCE_DB_SSL_SECRET_KEYS
                ;;
            target-db)
                list_secrets $secret_name TARGET_DB_SECRET_KEYS
                ;;
            target-db-ssl)
                list_secrets $secret_name TARGET_DB_SSL_SECRET_KEYS
                ;;
        esac
    done
}

get_secret() {
    if [ -n "$SECRET_SSL_NAME" ]; then
        print_secret "$SECRET_SSL_NAME" "$SECRET_SSL_KEY"
    else
        print_secret "$SECRET_NAME" "$SECRET_KEY"
    fi
}

set_secret() {
    if [ -n "$SECRET_SSL_NAME" ]; then
        update_ssl_secret "$SECRET_SSL_NAME" "$SECRET_SSL_KEY" "$SECRET_VALUE" "no"
        update_secret "$SECRET_NAME" "$SECRET_KEY" "$SECRET_SSL_PATH" "no"
    else
        update_secret "$SECRET_NAME" "$SECRET_KEY" "$SECRET_VALUE" "no"
    fi
}

delete_secret() {
    if [ -n "$SECRET_SSL_NAME" ]; then
        update_ssl_secret "$SECRET_SSL_NAME" "$SECRET_SSL_KEY" "$SECRET_VALUE" "yes"
        update_secret "$SECRET_NAME" "$SECRET_KEY" "$SECRET_SSL_PATH" "yes"
    else
        update_secret "$SECRET_NAME" "$SECRET_KEY" "$SECRET_VALUE" "yes"
    fi
}

update_secret() {
    local secret_name=$1
    local secret_key=$2
    local secret_value=$3
    local should_delete=$4

    # Get secret values from the Kubernetes secret for the specified secret name and namespace as json
    local secret_values=`$KUBECTL_COMMAND get secrets $secret_name --namespace=$RDI_NAMESPACE -o jsonpath='{.data}'`

    # Generate the kubectl command to create or update the secret
    local kubectl_command_args="create secret generic $secret_name --namespace=$RDI_NAMESPACE "

    if [ "$should_delete" == "no" ]; then
        kubectl_command_args+="--from-literal=$secret_key=$secret_value "
    fi

    while IFS="=" read -r key value; do
        # key equals the secret key continue (already added)
        if [ "$key" == "$secret_key" ]; then
            continue
        fi

        # Decode the base64 value
        value=$(echo "$value" | base64 --decode 2>/dev/null)

        if [ -z "$value" ]; then
            value=""
        fi

        kubectl_command_args+="--from-literal=$key=$value "
    done < <(echo "$secret_values" | jq -r 'to_entries[] | "\(.key)=\(.value)"')

    kubectl_command_args+="--save-config --dry-run=client -o yaml"

    execute_command "$kubectl_command_args"
}

update_ssl_secret() {
    local secret_ssl_name=$1
    local secret_ssl_key=$2
    local secret_ssl_path=$3
    local should_delete=$4

    # Get secret values from the Kubernetes secret for the specified secret name and namespace as json
    local secret_values=`$KUBECTL_COMMAND get secrets $secret_ssl_name --namespace=$RDI_NAMESPACE -o jsonpath='{.data}'`

    # Generate the kubectl command to create or update the secret
    local kubectl_command_args="create secret generic $secret_ssl_name --namespace=$RDI_NAMESPACE "

    if [ "$should_delete" == "no" ]; then
        kubectl_command_args+="--from-file=$secret_ssl_key=$secret_ssl_path "
    fi

    while IFS="=" read -r key value; do
        # key equals the secret key continue (already added)
        if [ "$key" == "$secret_ssl_key" ]; then
            continue
        fi

        # Decode the base64 value
        value=$(echo "$value" | base64 --decode 2>/dev/null)

        if [ -z "$value" ]; then
            value=""
        fi

        kubectl_command_args+="--from-literal=$key=\"$value\" "
    done < <(echo "$secret_values" | jq -r 'to_entries[] | "\(.key)=\(.value)"')

    kubectl_command_args+="--save-config --dry-run=client -o yaml"

    execute_command "$kubectl_command_args"
}

execute_command() {
    local kubectl_command_args=$1
    local command="$KUBECTL_COMMAND $kubectl_command_args 2>/dev/null"

    if [ "$DRY_RUN" == "no" ]; then
        command+=" | kubectl apply -f -"
    fi

    eval "$command"
}

print_secret() {
    local secret_name=$1
    local secret_key=$2

    local output=$($KUBECTL_COMMAND get secrets $secret_name --namespace=$RDI_NAMESPACE -o yaml 2>/dev/null | grep "$secret_key: " | awk '{print $2}' | base64 --decode 2>/dev/null)
    echo "$output"
}

if [ $# -lt 1 ]; then
  print_help
  exit 1
fi

case "$COMMAND" in
    $LIST_COMMAND)
        if [ $# -gt 3 ]; then
            echo "Error: Invalid number of arguments for list command."
            print_help
            exit 1
        fi
        ;;
    $GET_COMMAND)
        if [ $# -lt 2 ] || [ $# -gt 4 ]; then
            echo "Error: Invalid number of arguments for get command."
            print_help
            exit 1
        fi
        SECRET_KEY=$2
        SECRET_VALUE=""
        ;;
    $SET_COMMAND)
        if [ $# -lt 3 ] || [ $# -gt 6 ]; then
            echo "Error: Invalid number of arguments for set command."
            print_help
            exit 1
        fi
        SECRET_KEY=$2
        SECRET_VALUE=$3
        ;;
    $DELETE_COMMAND)
        if [ $# -lt 2 ] || [ $# -gt 4 ]; then
            echo "Error: Invalid number of arguments for delete command."
            print_help
            exit 1
        fi
        SECRET_KEY=$2
        SECRET_VALUE=""
        ;;
    -h|--help)
        print_help
        exit 0
        ;;
    *)
        echo "Unknown command: $COMMAND"
        print_help
        exit 1
        ;;
esac

while [ "$#" -gt 0 ]; do
  case "$2" in
    --namespace)
      if [ -z "$3" ] || [ "$3" == "--dry-run" ]; then
          echo "Error: Namespace not provided."
          print_help
          exit 1
      fi
      RDI_NAMESPACE=$3
      shift
      ;;
    --dry-run)
      DRY_RUN="yes"
      ;;
    *)
      if [[ "$2" == --* ]]; then
          echo "Error: Unknown parameter passed: $2"
          print_help
          exit 1
      fi
      ;;
  esac
  shift
done

# Set the secret name based on the secret key
if [ -v SECRET_NAMES[$SECRET_KEY] ]; then
    SECRET_NAME=${SECRET_NAMES[$SECRET_KEY]}
fi

# Check if the secret name is empty and exit if it is with an error message
if [ "$COMMAND" != $LIST_COMMAND ] && [ -z "$SECRET_NAME" ]; then
    echo "Error: Invalid secret key provided '$SECRET_KEY'."
    echo "Valid secret keys are: ${!SECRET_NAMES[@]}"
    echo ""
    print_help
    exit 1
fi

# Set the secret ssl name based on the secret key
if [ -v SECRET_SSL_NAMES[$SECRET_KEY] ]; then
    SECRET_SSL_NAME=${SECRET_SSL_NAMES[$SECRET_KEY]}

    # Set the secret ssl key based on the secret key
    SECRET_SSL_KEY=${SECRET_SSL_KEYS[$SECRET_KEY]}

    # Set the predefined secret ssl value based on the secret key
    SECRET_SSL_PATH=${PREDEFINED_SECRET_SSL_PATHS[$SECRET_KEY]}
fi

case "$COMMAND" in
    $LIST_COMMAND)
        list
        ;;
    $GET_COMMAND)
        get_secret
        ;;
    $SET_COMMAND)
        set_secret
        ;;
    $DELETE_COMMAND)
        delete_secret
        ;;
esac
