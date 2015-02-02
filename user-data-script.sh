#!/bin/bash

[[ "$TRACE" ]] && set -x

: ${IMAGES:=sequenceiq/ambari:1.7.0-consul sequenceiq/consul:v0.4.1.ptr}

install_utils() {
  apt-get update && apt-get install -y unzip curl git python-pip dnsutils nmap
  curl -o /usr/local/bin/jq http://stedolan.github.io/jq/download/linux64/jq && chmod +x /usr/local/bin/jq
  pip install awscli
  curl -Lsk https://github.com/progrium/plugn/releases/download/v0.1.0/plugn_0.1.0_linux_x86_64.tgz|tar -xzC /usr/local/bin/
}

install_docker() {
  curl -sSL https://get.docker.com/ | sh
  sudo usermod -aG docker ubuntu
}

install_consul() {
  curl -LO https://dl.bintray.com/mitchellh/consul/0.4.1_linux_amd64.zip \
    && unzip 0.4.1_linux_amd64.zip \
    && mv consul /usr/local/bin
}

pull_images() {
  for i in ${IMAGES}; do
    docker pull ${i}
  done
}

install_scripts() {
  curl -o /usr/local/register-ambari.sh https://gist.githubusercontent.com/doktoric/bbc20ec450573697c348/raw/register-ambari && chmod +x /usr/local/register-ambari.sh
  curl -o /usr/local/public_host_script.sh https://gist.githubusercontent.com/doktoric/41a28da9e974029d95d2/raw/ec2-host && chmod +x /usr/local/public_host_script.sh
  curl -o /usr/local/disk_mount.sh https://gist.githubusercontent.com/doktoric/0277e537cd97b0d9762f/raw/ec2-disk && chmod +x /usr/local/disk_mount.sh
  cp /usr/local/register-ambari.sh /etc/init.d/register-ambari
  chmod +x /etc/init.d/register-ambari
  chown root:root /etc/init.d/register-ambari
  update-rc.d -f register-ambari defaults
  update-rc.d -f register-ambari enable
}

fix_fstab() {
	sed -i "/dev\/xvdb/ d" /etc/fstab
}

main() {
    install_utils
    install_docker
    pull_images
    install_consul
    install_scripts
    fix_fstab
    touch /tmp/ready
}

[[ "$0" == "$BASH_SOURCE" ]] && main "$@"
