---
title: DIY homelab PC
date: 2023-11-13 20:45:35
tags: DIY
categories: Hardware
summary: Got a new way to write blog in english. Suppose to write the version 1 of this easy in chinese, then translating the recordes into English.
By the way, this one is about the  prepare of testing environments on my homelab PC.
Hope one day I can know more professional words.
---

## 1. Computer Parts
|配件|规格|价格|
|:---:|:---:|:---:|
|Motherboard|华南x99双路8D4|730含以下二者|
|CPU|E5-2680V4||
|Cooler|寒冰A500四铜管||
|RAM|闲鱼-镁光窄条2133-16G*4|280|
|GPU|GTX750 4G 貌似全新|335|
|Chassis|刀客360|150|
|Fan|PDD-纯白*5|48|
|SSD|BU KING 512G|150|
|Power|华南U700双路电源600W|243|
|Tools|硅脂、螺丝刀、网线|25|

## 2. Install PVE System
- Ventoy
- proxmox-ve_8.0-2.iso

### 2.1 Disable the subscription on web UI

```bash
sed -i_orig "s/data.status === 'Active'/true/g" /usr/share/pve-manager/js/pvemanagerlib.js
sed -i_orig "s/if (res === null || res === undefined || \!res || res/if(/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
sed -i_orig "s/.data.status.toLowerCase() !== 'active'/false/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
systemctl restart pveproxy
```

### 2.2 Network
- [reference](https://www.bilibili.com/video/BV1xH4y1f7Ga/?spm_id_from=333.337.search-card.all.click&vd_source=154006e70f5c14d792db947270b63614)
- pve host using a vitual NIC and bridging the network connection to a physical NIC

```shell
cat /etc/network/interfaces
auto lo
iface lo inet loopback
iface enp6s0 inet manual    # physical NIC

auto vmbr0               # Vitrual NIC
iface vmbr0 inet static
        address 192.168.3.20/24
        gateway 192.168.3.1
        bridge-ports enp6s0     #bridging
        bridge-stp off
        bridge-fd 0
```

```shell
sudo systemctl restart networking 
```

### 2.3 [ Changing into a homeland repository source](https://www.wunote.cn/article/10000)

```shell
# modify the ubuntu software source
wget https://mirrors.ustc.edu.cn/proxmox/debian/proxmox-release-bookworm.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg

echo "deb https://mirrors.ustc.edu.cn/proxmox/debian bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list

sed -i 's|^deb http://ftp.debian.org|deb https://mirrors.ustc.edu.cn|g' /etc/apt/sources.list

sed -i 's|^deb http://security.debian.org|deb https://mirrors.ustc.edu.cn/debian-security|g' /etc/apt/sources.list

# modify the ceph repository source
echo "deb https://mirrors.ustc.edu.cn/proxmox/debian/ceph-quincy bookworm no-subscription" > /etc/apt/sources.list.d/ceph.list

# CT images source
sed -i 's|http://download.proxmox.com|https://mirrors.ustc.edu.cn/proxmox|g' /usr/share/perl5/PVE/APLInfo.pm

sed -i 's/^/#/' /etc/apt/sources.list.d/pve-enterprise.list
```

## 3. Virtual machine On pve host

### 3.1 SYS
- ubuntu 22.04.3 server
- choose network bridging on vmbr0, it's convenient and fast. also because of my simple network architecture.

### 3.2 Repository Source

```
deb https://mirrors.ustc.edu.cn/ubuntu/ jammy main restricted universe multiverse

deb https://mirrors.ustc.edu.cn/ubuntu/ jammy-security main restricted universe multiverse

deb https://mirrors.ustc.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse

deb https://mirrors.ustc.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse
```

### 3.3 Install containerd、nerdctl & make this vm as a template

```shell
apt install containerd
containerd config default > /etc/containerd/config.toml  # generating a default configuration of containerd
```

- Modify part of this file, like below example.

```toml
sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.8"
SystemdCgroup = true

[plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = ["https://bqr1dr1n.mirror.aliyuncs.com"]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."k8s.gcr.io"]
          endpoint = ["https://registry.aliyuncs.com/google_containers"]
```

- Install the nerdctl by binary package

```shell
wget https://download.fastgit.org/containerd/nerdctl/releases/download/v0.12.1/nerdctl-0.12.1-linux-amd64.tar.gz
mkdir -p /usr/local/containerd/bin/ && tar -zxvf nerdctl-0.12.1-linux-amd64.tar.gz nerdctl && mv nerdctl /usr/local/containerd/bin/
ln -s /usr/local/containerd/bin/nerdctl /usr/local/bin/nerdctl
```

### 3.4 System settings

```bash
# ipv4 forward
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward

# swap
swapoff -a

vim /etc/fstab
  # /swap.img      none    swap    sw      0       0
```

- Transform this vm into template by Web UI of pve

## 4. Kubernetes

### 4.1 Install kubeadm kubelet kubectl

```bash
echo deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main > /etc/apt/sources.list.d/kubernetes.list
curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | \
	apt-key add -
apt-get update && apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
```

### 4.2 generate a default configuration file in workspace path to init the cluster

```
kubeadm config print init-defaults --component-configs KubeletConfiguration > kubeadm.yaml
```

- modify part of configuration file

```yaml
localAPIEndpoint:
  advertiseAddress: 192.168.3.11  #master IP
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  imagePullPolicy: IfNotPresent
    #name: master1  # defaults to be node
  taints: null
---
apiServer:
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta3
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager: {}
dns: {}
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: registry.aliyuncs.com/google_containers  #changing into repository in china
kind: ClusterConfiguration
kubernetesVersion: 1.28.0    # specify the version of kube
networking:
  dnsDomain: cluster.local
  podSubnet: 10.244.0.0/16    # need to add
  serviceSubnet: 10.96.0.0/12
scheduler: {}
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1 # add
kind: KubeProxyConfiguration
mode: ipvs
```

- init cluster

```
sudo kubeadm init --config kubeadm-config.yaml
``` 

- work nodes joining the cluster

```
kubeadm join 192.168.3.14:6443 --token n8orxj.f51riixygulit9yz \
        --discovery-token-ca-cert-hash sha256:c0af38d55001f6eaf09ca9248db5e048c492ee4b883f0534a54187eceb50a928
```

- after all the work nodes joining the cluster, deploy the flannel

```bash
wget https://raw.githubusercontent.com/flannel-io/flannel/v0.20.1/Documentation/kube-flannel.yml
kubectl apply -f kube-flannel.yml
```

- check status of cluster

```
kubectl get nodes -A
kubectl get pods -A
```

## 5. Fault
### 5.1 kubectl get nodes
- descriobe

```shell
couldn't get current server API group list: Get "http://localhost:8080/api?timeout=32s": dial tcp 127.0.0.1:8080: connect: connection refused
The connection to the server localhost:8080 was refused - did you specify the right host or port?
```

- solution: fogot to apply the config, it's printed by the kubeadm 

```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### 5.2 The kubelet is not running
- describe

```shell
[kubelet-check] Initial timeout of 40s passed.

Unfortunately, an error has occurred:
        timed out waiting for the condition

This error is likely caused by:
        - The kubelet is not running
        - The kubelet is unhealthy due to a misconfiguration of the node in some way (required cgroups disabled)
```

- solution: changing the wrong advertiseAddress, supoose to mine master IP.

```shell
# in some  conditions, this setting may help. It controls the cgroup driver of kubelet
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
``` 

### 5.3 coredns halting on creating status.
- describe

```shell
Warning  FailedCreatePodSandBox  42s   kubelet            Failed to create pod sandbox: rpc error: code = Unknown desc = failed to setup network for sandbox "03e2b9a1ceaf66beb681891dc276ea490d664822b43047f25d3b5d4a11e76eb0": plugin type="flannel" failed (add): open /run/flannel/subnet.env: no such file or directory
```

- solutions: creating a file && reset the cluster and reinstall the kube-flannel. (also worked in this case: work not ready)

```shell
cat  /run/flannel/subnet.env  #  manual creating

FLANNEL_NETWORK=10.244.0.0/16
FLANNEL_SUBNET=10.244.0.1/24
FLANNEL_MTU=1450
FLANNEL_IPMASQ=true
```
