#!/bin/bash

# Configurable variables
REPO_NAME="TEST-ORG1"
ENVIRONMENTS=("common" "dev" "staging" "production")
PLAYBOOKS_REPO="git@github.com:sovereignlight2019/CasC-Playbooks.git"
CONFIG_DIRS=("credentials" "groups" "job_templates" "projects" "schedules" "workflow_job_templates" "credential_types" "inventories" "roles" "teams")

# Check for necessary environment variables
if [ -z "${ORG_ADMIN}" ] || [ -z "${ORG_PASSWORD}" ] || [ -z "${VAULT_PASSWORD}" ]; then
  echo "ORG_ADMIN, ORG_PASSWORD, and VAULT_PASSWORD environment variables must be set."
  echo "Current values:"
  echo "ORG_ADMIN: ${ORG_ADMIN}"
  echo "ORG_PASSWORD: ${ORG_PASSWORD}"
  echo "VAULT_PASSWORD: ${VAULT_PASSWORD}"
  exit 1
fi

# Initialize git repository if not already done
if [ ! -d ".git" ]; then
  git init
  git remote add origin git@github.com:your-username/${REPO_NAME}.git
fi

# Clone playbooks repository if it does not exist
if [ ! -d "playbooks" ]; then
  git clone $PLAYBOOKS_REPO playbooks
fi

# Create directory structure based on ENVIRONMENTS and CONFIG_DIRS
for env in "${ENVIRONMENTS[@]}"; do
  for dir in "${CONFIG_DIRS[@]}"; do
    mkdir -p environments/${env}/org_${dir}.d
  done
  mkdir -p inventory/${env}

  # Create inventory files if they do not exist
  if [ ! -f inventory/${env}/hosts ]; then
    cat <<EOL > inventory/${env}/hosts
[localhost]
localhost ansible_connection=local
EOL
  fi

  # Create main.yml for each environment if it does not exist
  if [ ! -f environments/${env}/main.yml ]; then
    touch environments/${env}/main.yml
  fi

  # Store and encrypt org credentials if they do not exist
  if [ ! -f environments/${env}/org_credentials.d/org_credentials.yml ]; then
    cat <<EOL > environments/${env}/org_credentials.d/org_credentials.yml
org_admin: ${ORG_ADMIN}
org_password: ${ORG_PASSWORD}
EOL
    ansible-vault encrypt environments/${env}/org_credentials.d/org_credentials.yml --vault-password-file <(echo -n "${VAULT_PASSWORD}")
  fi
done

# Example configurations for common environment
declare -A CONFIG_FILES
CONFIG_FILES[org_teams.d/teams.yml]="---
infra.controller_configuration.teams:
  - name: Team 1
    organization: $REPO_NAME
    description: Team 1 description
  - name: Team 2
    organization: $REPO_NAME
    description: Team 2 description
"

CONFIG_FILES[org_projects.d/projects.yml]="---
infra.controller_configuration.projects:
  - name: Project 1
    organization: $REPO_NAME
    scm_type: git
    scm_url: 'https://github.com/your-repo/project1.git'
  - name: Project 2
    organization: $REPO_NAME
    scm_type: git
    scm_url: 'https://github.com/your-repo/project2.git'
"

# Create example configuration files in common if they do not exist
for file in "${!CONFIG_FILES[@]}"; do
  if [ ! -f environments/common/$file ]; then
    echo "${CONFIG_FILES[$file]}" > environments/common/$file
  fi
done

echo "Repository setup complete."

