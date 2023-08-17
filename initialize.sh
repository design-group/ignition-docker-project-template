#!/usr/bin/env bash

pull_start_containers () {
    # Docker pull and start containers
    local MAX_WAIT_SECONDS=60
    local WAIT_INTERVAL=5
    local project="$1"
    local container_name="$2"
    local compose_file="$3"

    while true; do

        printf '\n\n Waiting for Docker container %s to start...\n' "${container_name}"
        docker-compose pull && docker-compose -f "${compose_file}" up -d

        elapsed_seconds=0
        while [ $elapsed_seconds -lt $MAX_WAIT_SECONDS ]; do
            container_status=$(docker ps -f "name=$container_name" --format "{{.Status}}")

            if [[ $container_status == *"Up"* ]] && [[ ! "${container_name}" == "proxy" ]]; then
                printf 'Container %s status: %s \n' "${container_name}" "${container_status}"
                printf 'access the gateway at http://%s.localtest.me' "${project}"
                break
            elif [[ $container_status == *"Up"* ]] && [[ "${container_name}" == "proxy" ]]; then
                printf 'Container %s status: %s \n' "${container_name}" "${container_status}"
                break
            fi

            sleep $WAIT_INTERVAL
            elapsed_seconds=$((elapsed_seconds + WAIT_INTERVAL))
        done

        if [ $elapsed_seconds -ge $MAX_WAIT_SECONDS ]; then
            printf 'Timed out waiting for container %s to start. \n' "${container_name}"
            printf 'Container %s status: %s \n' "${container_name}" "${container_status}"
        fi

        
        break
    done
}

printf '\n\n Ignition Architecture Initialization'
printf '\n ==================================================================== \n'

read -rep $'Enter project name: ' project_name

# Update local files with project name
printf '\n\n Renaming file %s.code-workspace... \n' "${project_name}"
mv ./*.code-workspace "${project_name}".code-workspace

printf 'Creating .env file for the %s project... \n' "${project_name}"
cat << EOF > ./.env
COMPOSE_PATH_SEPARATOR=:
COMPOSE_FILE=docker-compose.yaml:docker-compose.traefik.yaml
COMPOSE_PROJECT_NAME=${project_name}
EOF

printf 'Updating Traefik compose file and README file with %s. \n' "${project_name}"
sed -i "s/ignition-template/${project_name}/g" docker-compose.traefik.yaml
sed -i "s/<project-name>/${project_name}/g" README.md

mkdir -p ignition-data

# Git
printf '\n\n Commiting changes... \n'
git add .
git commit -m "Initial commit"

# Setup and start Docker for reverse proxy
if [ ! -f "${HOME}"/traefik-proxy/docker-compose.yml ]; 
then
    printf '\n\n Traefik Proxy not found in home directory. \n'
    install_path="${HOME}"/traefik-proxy/
    echo "${install_path}"
    read -rep $'\n Would you like to use the default path (y/n)?' use_default

    case "${use_default}" in
        [Yy]* ) 
            mkdir -p "${install_path}";;
        [Nn]* )
            install_path=""
            while true; do
                if [ -d "${install_path}" ]; then
                    echo "${install_path}"
                    ls -al "${install_path}"
                    read -rep $'\n\n Would you like to clone the design-group/traefik-proxy to your local PC in this location? (y/n) \n' install_proxy
                    case "${install_proxy}" in
                        [Yy]* )
                            break;;
                        [Nn]* )
                            install_path="";;
                        * ) 
                            printf 'Please answer y or n. \n';;
                    esac
                else
                    read -rep $'\n Please enter a valid empty folder path to clone into [Format: /home/user/traefik-proxy/]: ' install_path
                    if [[ "$install_path" =~ ^(/[^/ ]*)+/?$ ]]; then
                        mkdir -p "${install_path}"
                    fi
                fi;
            done;;
        * )
            printf 'Please answer y or n. \n'
    esac

    printf 'Cloning design-group/traefik-proxy into %s...\n' "${install_path}"
    git clone https://github.com/design-group/traefik-proxy.git "${install_path}"
    pull_start_containers "${project_name}" proxy "${install_path}"/docker-compose.yml
else
    printf '\n\n Traefik Proxy found in home directory. \n'
fi

# Setup and start Docker for Gateway
while true; do
    read -rep $'\n\n Do you want to pull any changes to the Docker image and start the Ignition Gateway container? (y/n) \n' start_container
    case "${start_container}" in
        [Yy]* ) 
            pull_start_containers "${project_name}" "${project_name}-gateway-1" ./docker-compose.yaml;
            break;;
        [Nn]* ) 
            printf '\n\n Please run: \n docker-compose pull && docker-compose up -d'
            printf '\n Once the container is started, in a web browser, access the gateway at http://%s.localtest.me' "${project_name}";
            break;;
        * ) 
            printf 'Please answer y or n.';;
    esac
done

printf '\n\n\n Ignition architecture initialization finished!'
printf '\n ==================================================================== \n'