#!/bin/bash
# This script is used to join one or more nodes as masters
echo "$@"

mkdir -p /etc/rancher/k3s
mkdir -p /var/lib/rancher/k3s/server/logs
cat <<EOF >>/etc/rancher/k3s/config.yaml
write-kubeconfig-mode: "0644"
tls-san:
  - ${2}
token: ${8}
EOF

if [[ -n "${10}" ]] && [[ "${10}" == *":"* ]]
then
   echo -e "${10}" >> /etc/rancher/k3s/config.yaml
   cat /etc/rancher/k3s/config.yaml
fi

if [[ -n "${10}" ]] && [[ "${10}" == *"protect-kernel-defaults"* ]]
then
  mkdir -p /var/lib/rancher/k3s/server/manifests
  if [[ "${1}" == *"centos"* ]] || [[ "${1}" == *"rhel"* ]] || [[ "${1}" == *"rocky"* ]]
  then
    yum -y install bc
  fi
  calc(){ awk "BEGIN { print "$*" }"; }
  version=`echo ${4}|cut -c2-5`
  conversion=$(calc $version*1)
  if (( $(echo "$conversion >= 1.25" | bc -l) ))
  then
    sed -i "s/enforce: \"privileged\"/enforce: \"${14}\"/g" /tmp/cluster-level-pss.yaml
    cat /tmp/cis_v125_masterconfig.yaml >> /etc/rancher/k3s/config.yaml
    cat /tmp/v125_policy.yaml > /var/lib/rancher/k3s/server/manifests/policy.yaml
    cat /tmp/cluster-level-pss.yaml > /var/lib/rancher/k3s/server/cluster-level-pss.yaml
  else
    cat /tmp/cis_masterconfig.yaml >> /etc/rancher/k3s/config.yaml
    cat /tmp/policy.yaml > /var/lib/rancher/k3s/server/manifests/policy.yaml
  fi
  echo -e "vm.panic_on_oom=0" >>/etc/sysctl.d/90-kubelet.conf
  echo -e "vm.overcommit_memory=1" >>/etc/sysctl.d/90-kubelet.conf
  echo -e "kernel.panic=10" >>/etc/sysctl.d/90-kubelet.conf
  echo -e "kernel.panic_on_oops=1" >>/etc/sysctl.d/90-kubelet.conf
  echo -e "kernel.keys.root_maxbytes=25000000" >>/etc/sysctl.d/90-kubelet.conf
  sysctl -p /etc/sysctl.d/90-kubelet.conf
  systemctl restart systemd-sysctl
  cat /tmp/audit.yaml > /var/lib/rancher/k3s/server/audit.yaml
  if [[ "${4}" == *"v1.18"* ]] || [[ "${4}" == *"v1.19"* ]] || [[ "${4}" == *"v1.20"* ]]
  then
    cat /tmp/v120ingresspolicy.yaml > /var/lib/rancher/k3s/server/manifests/v120ingresspolicy.yaml
  else
    cat /tmp/v121ingresspolicy.yaml > /var/lib/rancher/k3s/server/manifests/v121ingresspolicy.yaml
  fi
fi

if [ "${1}" = "rhel" ]
then
   subscription-manager register --auto-attach --username="${11}" --password="${12}"
   subscription-manager repos --enable=rhel-7-server-extras-rpms
fi
export "${3}"="${4}"
if [ "${5}" = "etcd" ]
then
    if [[ "${4}" == *"v1.18"* ]] || [["${4}" == *"v1.17"* ]] && [[ -n "${10}" ]]
    then
        curl -sfL https://get.k3s.io | INSTALL_K3S_TYPE='server' sh -s - server --server https://"${7}":6443 --token "${8}" --node-external-ip="${6}" --tls-san "${2}" --write-kubeconfig-mode "0644"
    else
        if [ ${13} != "null" ]
        then
          curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=${13} INSTALL_K3S_TYPE='server' sh -s - server --server https://"${7}":6443 --node-external-ip="${6}"
        else
          curl -sfL https://get.k3s.io | INSTALL_K3S_TYPE='server' sh -s - server --server https://"${7}":6443 --node-external-ip="${6}"
        fi
    fi
else
   if [[ "${4}" == *"v1.18"* ]] || [["${4}" == *"v1.17"* ]] && [[ -n "${10}" ]]
    then
        curl -sfL https://get.k3s.io | INSTALL_K3S_TYPE='server' sh -s - server --node-external-ip="${6}" --datastore-endpoint="${9}" --tls-san "${2}" --write-kubeconfig-mode "0644"
    else
        if [ ${13} != "null" ]
        then
          curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=${13} INSTALL_K3S_TYPE='server' sh -s - server --node-external-ip="${6}" --datastore-endpoint="${9}"
        else
          curl -sfL https://get.k3s.io | INSTALL_K3S_TYPE='server' sh -s - server --node-external-ip="${6}" --datastore-endpoint="${9}"
        fi
    fi
fi
