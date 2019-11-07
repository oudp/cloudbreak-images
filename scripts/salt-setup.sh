#!/bin/bash

: ${DEBUG:=1}
: ${DRY_RUN:-1}

set -e -o pipefail -o errexit

function add-freeipa-repo {
  if [ "${OS}" == "debian9" ]; then
    #Add freeipa repo to debian repository list
    cat << EOF > /etc/apt/sources.list.d/freeipa.list
deb http://apt.numeezy.fr stretch main
deb-src http://apt.numeezy.fr stretch main
EOF

    #Add signature verification key
    wget -qO - http://apt.numeezy.fr/numeezy.asc | apt-key add -
    #Update package list
    apt-get update
  fi
}

function prepare {
  sudo chown -R root:root /tmp/saltstack
  add-freeipa-repo
  apply_amazonlinux_salt_patch
}

function copy_resources {
  local saltenv=${1}
  sudo mkdir -p /srv/salt/${saltenv} /srv/pillar/${saltenv}
  sudo cp -R /tmp/saltstack/${saltenv}/salt/* /srv/salt/${saltenv}
  if [ -d "/tmp/saltstack/${saltenv}/pillar" ]
  then
    sudo cp -R /tmp/saltstack/${saltenv}/pillar/* /srv/pillar/${saltenv}
  fi
}
  #Needed because of https://github.com/saltstack/salt/issues/47258
function apply_amazonlinux_salt_patch {
  if [ "${OS}" == "amazonlinux" ] && [ -f /tmp/saltstack/config/minion ] && ! grep -q "rh_service" /tmp/saltstack/config/minion ; then
    tee -a /tmp/saltstack/config/minion << EOF
providers:
  service: rh_service
EOF
  fi
}

function highstate {
  local saltenv=${1}
  copy_resources ${saltenv}
  ${SALT_PATH}/bin/salt-call --local state.highstate saltenv=${saltenv} --retcode-passthrough -l info --log-file=/tmp/salt-build-${saltenv}.log --log-file-level=info --config-dir=/tmp/saltstack/config
}

function apply_optional_states {
  echo "Running applying optional states: ${OPTIONAL_STATES}"

  if [ -n "${OPTIONAL_STATES}" ]
  then
    local saltenv="optional"
    copy_resources ${saltenv}
    ${SALT_PATH}/bin/salt-call --local state.sls ${OPTIONAL_STATES} saltenv=${saltenv} pillarenv=${saltenv} --retcode-passthrough -l info --log-file=/tmp/salt-build-${saltenv}.log --config-dir=/tmp/saltstack/config
  fi
}

: ${CUSTOM_IMAGE_TYPE:=$1}

case ${CUSTOM_IMAGE_TYPE} in
  base|"")
    echo "Running highstate for Base.."
    prepare
    highstate "base"
  ;;
  freeipa)
    echo "Running highstate for FreeIPA.."
    prepare
    highstate "base"
    highstate "freeipa"
  ;;
  hortonworks)
    echo "Running highstate for Base and Hortonworks.."
    prepare
    highstate "base"
    highstate "hortonworks"
  ;;
  *)
    echo "Unsupported CUSTOM_IMAGE_TYPE:" ${CUSTOM_IMAGE_TYPE}
    exit 1
  ;;
esac

apply_optional_states

echo "Running validation and cleanup"
highstate "final"
