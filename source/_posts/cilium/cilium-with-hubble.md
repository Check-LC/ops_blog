---
title: Cilium with Hubble
author: LC
toc: true
date: 2024-06-06 2024:10:05
img:
top:
cover:
password:
summary: 使用 cilium 网络插件，并暴露其 hubble 的监控 UI
categories: Kubernetes
tags: ['cilium', 'kubernetes', 'hubble']
---



## 前情
1. rancher 集群，将 calico 替换为 cilium ；删除当前 calico-system 的资源
## 安装cilium
1. 进入集群管理中修改集群 yaml 中，spec.machineGlobalConfig.cni
2. 编辑集群配置，修改附加配置中的 cilium 的 values
```
.Values.hubble.metrics.enableOpenMetrics: true
.Values.hubble.metrics.enabled: 
    - dns:query;ignoreAAAA  
    - drop  
    - tcp  
    - flow  
    - icmp  
    - http
.Values.hubble.relay.enabled: true
.Values.hubble.relay.prometheus.enabled: true
.Values.hubble.ui.enabled: true  # 有必要对此做ingress
.Values.envoy.enabled: true
.Values.envoy.prometheus.enabled: true
```

1. 服务自动发现的问题
```
Get "http://10.8.0.87:9964/metrics?kubernetes_io_managed_by=Helm&kubernetes_io_name=cilium-agent&kubernetes_io_part_of=cilium": dial tcp 10.8.0.87:9964: connect: connection refused
```

>[!solution]
> - 开启组件
> ```
> envoy:
>   enable: true
> ```

- 集群中 cilium 的当前测试下的完整 values


```yaml
MTU: 0
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            k8s-app: cilium
        topologyKey: kubernetes.io/hostname
agent: true
agentNotReadyTaintKey: node.cilium.io/agent-not-ready
aksbyocni:
  enabled: false
alibabacloud:
  enabled: false
annotateK8sNode: false
annotations: {}
apiRateLimit: null
authentication:
  enabled: true
  gcInterval: 5m0s
  mutual:
    connectTimeout: 5s
    port: 4250
    spire:
      adminSocketPath: /run/spire/sockets/admin.sock
      agentSocketPath: /run/spire/sockets/agent/agent.sock
      annotations: {}
      connectionTimeout: 30s
      enabled: false
      install:
        agent:
          affinity: {}
          annotations: {}
          image:
            digest: >-
              sha256:99405637647968245ff9fe215f8bd2bd0ea9807be9725f8bf19fe1b21471e52b
            override: null
            pullPolicy: IfNotPresent
            repository: ghcr.io/spiffe/spire-agent
            tag: 1.8.5
            useDigest: true
          labels: {}
          nodeSelector: {}
          podSecurityContext: {}
          securityContext: {}
          serviceAccount:
            create: true
            name: spire-agent
          skipKubeletVerification: true
          tolerations:
            - effect: NoSchedule
              key: node.kubernetes.io/not-ready
            - effect: NoSchedule
              key: node-role.kubernetes.io/master
            - effect: NoSchedule
              key: node-role.kubernetes.io/control-plane
            - effect: NoSchedule
              key: node.cloudprovider.kubernetes.io/uninitialized
              value: 'true'
            - key: CriticalAddonsOnly
              operator: Exists
        enabled: true
        existingNamespace: false
        initImage:
          digest: >-
            sha256:223ae047b1065bd069aac01ae3ac8088b3ca4a527827e283b85112f29385fb1b
          override: null
          pullPolicy: IfNotPresent
          repository: docker.io/library/busybox
          tag: 1.36.1
          useDigest: true
        namespace: cilium-spire
        server:
          affinity: {}
          annotations: {}
          ca:
            keyType: rsa-4096
            subject:
              commonName: Cilium SPIRE CA
              country: US
              organization: SPIRE
          dataStorage:
            accessMode: ReadWriteOnce
            enabled: true
            size: 1Gi
            storageClass: null
          image:
            digest: >-
              sha256:28269265882048dcf0fed32fe47663cd98613727210b8d1a55618826f9bf5428
            override: null
            pullPolicy: IfNotPresent
            repository: ghcr.io/spiffe/spire-server
            tag: 1.8.5
            useDigest: true
          initContainers: []
          labels: {}
          nodeSelector: {}
          podSecurityContext: {}
          securityContext: {}
          service:
            annotations: {}
            labels: {}
            type: ClusterIP
          serviceAccount:
            create: true
            name: spire-server
          tolerations: []
      serverAddress: null
      trustDomain: spiffe.cilium
  queueSize: 1024
  rotatedIdentitiesQueueSize: 1024
autoDirectNodeRoutes: false
azure:
  enabled: false
bandwidthManager:
  bbr: false
  enabled: false
bgp:
  announce:
    loadbalancerIP: false
    podCIDR: false
  enabled: false
bgpControlPlane:
  enabled: false
  secretsNamespace:
    create: false
    name: kube-system
bpf:
  authMapMax: null
  autoMount:
    enabled: true
  ctAnyMax: null
  ctTcpMax: null
  hostLegacyRouting: null
  lbExternalClusterIP: false
  lbMapMax: 65536
  mapDynamicSizeRatio: null
  masquerade: null
  monitorAggregation: medium
  monitorFlags: all
  monitorInterval: 5s
  natMax: null
  neighMax: null
  policyMapMax: 16384
  preallocateMaps: false
  root: /sys/fs/bpf
  tproxy: null
  vlanBypass: null
bpfClockProbe: false
certgen:
  affinity: {}
  annotations:
    cronJob: {}
    job: {}
  extraVolumeMounts: []
  extraVolumes: []
  image:
    override: null
    pullPolicy: IfNotPresent
    repository: rancher/mirrored-cilium-certgen
    tag: v0.1.9
    useDigest: false
  podLabels: {}
  tolerations: []
  ttlSecondsAfterFinished: 1800
cgroup:
  autoMount:
    enabled: true
    resources: {}
  hostRoot: /run/cilium/cgroupv2
cleanBpfState: false
cleanState: false
cluster:
  id: 0
  name: default
clustermesh:
  annotations: {}
  apiserver:
    affinity:
      podAntiAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                k8s-app: clustermesh-apiserver
            topologyKey: kubernetes.io/hostname
    etcd:
      init:
        extraArgs: []
        extraEnv: []
        resources: {}
      lifecycle: {}
      resources: {}
      securityContext: {}
    extraArgs: []
    extraEnv: []
    extraVolumeMounts: []
    extraVolumes: []
    image:
      override: null
      pullPolicy: IfNotPresent
      repository: rancher/mirrored-cilium-clustermesh-apiserver
      tag: v1.15.1
      useDigest: false
    kvstoremesh:
      enabled: false
      extraArgs: []
      extraEnv: []
      extraVolumeMounts: []
      lifecycle: {}
      resources: {}
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
    lifecycle: {}
    metrics:
      enabled: true
      etcd:
        enabled: true
        mode: basic
        port: 9963
      kvstoremesh:
        enabled: true
        port: 9964
      port: 9962
      serviceMonitor:
        annotations: {}
        enabled: false
        etcd:
          interval: 10s
          metricRelabelings: null
          relabelings: null
        interval: 10s
        kvstoremesh:
          interval: 10s
          metricRelabelings: null
          relabelings: null
        labels: {}
        metricRelabelings: null
        relabelings: null
    nodeSelector:
      kubernetes.io/os: linux
    podAnnotations: {}
    podDisruptionBudget:
      enabled: false
      maxUnavailable: 1
      minAvailable: null
    podLabels: {}
    podSecurityContext: {}
    priorityClassName: ''
    replicas: 1
    resources: {}
    securityContext: {}
    service:
      annotations: {}
      externalTrafficPolicy: null
      internalTrafficPolicy: null
      nodePort: 32379
      type: NodePort
    terminationGracePeriodSeconds: 30
    tls:
      admin:
        cert: ''
        key: ''
      authMode: legacy
      auto:
        certManagerIssuerRef: {}
        certValidityDuration: 1095
        enabled: true
        method: helm
      client:
        cert: ''
        key: ''
      remote:
        cert: ''
        key: ''
      server:
        cert: ''
        extraDnsNames: []
        extraIpAddresses: []
        key: ''
    tolerations: []
    topologySpreadConstraints: []
    updateStrategy:
      rollingUpdate:
        maxUnavailable: 1
      type: RollingUpdate
  config:
    clusters: []
    domain: mesh.cilium.io
    enabled: false
  maxConnectedClusters: 255
  useAPIServer: false
cni:
  binPath: /opt/cni/bin
  chainingMode: portmap
  chainingTarget: null
  confFileMountPath: /tmp/cni-configuration
  confPath: /etc/cni/net.d
  configMapKey: cni-config
  customConf: false
  exclusive: true
  hostConfDirMountPath: /host/etc/cni/net.d
  install: true
  logFile: /var/run/cilium/cilium-cni.log
  resources:
    requests:
      cpu: 100m
      memory: 10Mi
  uninstall: false
conntrackGCInterval: ''
conntrackGCMaxInterval: ''
containerRuntime:
  integration: none
crdWaitTimeout: ''
customCalls:
  enabled: false
daemon:
  allowedConfigOverrides: null
  blockedConfigOverrides: null
  configSources: null
  runPath: /var/run/cilium
dashboards:
  annotations: {}
  enabled: false
  label: grafana_dashboard
  labelValue: '1'
  namespace: null
debug:
  enabled: false
  verbose: null
disableEndpointCRD: false
dnsPolicy: ''
dnsProxy:
  dnsRejectResponseCode: refused
  enableDnsCompression: true
  endpointMaxIpPerHostname: 50
  idleConnectionGracePeriod: 0s
  maxDeferredConnectionDeletes: 10000
  minTtl: 0
  preCache: ''
  proxyPort: 0
  proxyResponseMaxDelay: 100ms
egressGateway:
  enabled: false
  installRoutes: false
  reconciliationTriggerInterval: 1s
enableCiliumEndpointSlice: false
enableCriticalPriorityClass: true
enableIPv4BIGTCP: false
enableIPv4Masquerade: true
enableIPv6BIGTCP: false
enableIPv6Masquerade: true
enableK8sTerminatingEndpoint: true
enableMasqueradeRouteSource: false
enableRuntimeDeviceDetection: false
enableXTSocketFallback: true
encryption:
  enabled: false
  interface: ''
  ipsec:
    interface: ''
    keyFile: ''
    keyRotationDuration: 5m
    keyWatcher: true
    mountPath: ''
    secretName: ''
  keyFile: keys
  mountPath: /etc/ipsec
  nodeEncryption: false
  secretName: cilium-ipsec-keys
  strictMode:
    allowRemoteNodeIdentities: false
    cidr: ''
    enabled: false
  type: ipsec
  wireguard:
    persistentKeepalive: 0s
    userspaceFallback: false
endpointHealthChecking:
  enabled: true
endpointRoutes:
  enabled: false
endpointStatus:
  enabled: false
  status: ''
eni:
  awsEnablePrefixDelegation: false
  awsReleaseExcessIPs: false
  ec2APIEndpoint: ''
  enabled: false
  eniTags: {}
  gcInterval: ''
  gcTags: {}
  iamRole: ''
  instanceTagsFilter: []
  subnetIDsFilter: []
  subnetTagsFilter: []
  updateEC2AdapterLimitViaAPI: true
envoy:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              k8s-app: cilium-envoy
          topologyKey: kubernetes.io/hostname
  annotations: {}
  connectTimeoutSeconds: 2
  dnsPolicy: null
  enabled: true
  extraArgs: []
  extraContainers: []
  extraEnv: []
  extraHostPathMounts: []
  extraVolumeMounts: []
  extraVolumes: []
  healthPort: 9878
  idleTimeoutDurationSeconds: 60
  image:
    override: null
    pullPolicy: IfNotPresent
    repository: rancher/mirrored-cilium-cilium-envoy
    tag: v1.27.3-713b673cccf1af661efd75ca20532336517ddcb9
    useDigest: false
  livenessProbe:
    failureThreshold: 10
    periodSeconds: 30
  log:
    format: '[%Y-%m-%d %T.%e][%t][%l][%n] [%g:%#] %v'
    path: ''
  maxConnectionDurationSeconds: 0
  maxRequestsPerConnection: 0
  nodeSelector:
    kubernetes.io/os: linux
  podAnnotations: {}
  podLabels: {}
  podSecurityContext: {}
  priorityClassName: null
  prometheus:
    enabled: true
    port: '9964'
    serviceMonitor:
      annotations: {}
      enabled: false
      interval: 10s
      labels: {}
      metricRelabelings: null
      relabelings:
        - replacement: ${1}
          sourceLabels:
            - __meta_kubernetes_pod_node_name
          targetLabel: node
  readinessProbe:
    failureThreshold: 3
    periodSeconds: 30
  resources: {}
  rollOutPods: false
  securityContext:
    capabilities:
      envoy:
        - NET_ADMIN
        - SYS_ADMIN
    privileged: false
    seLinuxOptions:
      level: s0
      type: spc_t
  startupProbe:
    failureThreshold: 105
    periodSeconds: 2
  terminationGracePeriodSeconds: 1
  tolerations:
    - operator: Exists
  updateStrategy:
    rollingUpdate:
      maxUnavailable: 2
    type: RollingUpdate
envoyConfig:
  enabled: false
  secretsNamespace:
    create: true
    name: cilium-secrets
etcd:
  annotations: {}
  clusterDomain: cluster.local
  enabled: false
  endpoints:
    - https://CHANGE-ME:2379
  extraArgs: []
  extraVolumeMounts: []
  extraVolumes: []
  image:
    override: null
    pullPolicy: IfNotPresent
    repository: rancher/mirrored-cilium-cilium-etcd-operator
    tag: v2.0.7
    useDigest: false
  k8sService: false
  nodeSelector:
    kubernetes.io/os: linux
  podAnnotations: {}
  podDisruptionBudget:
    enabled: false
    maxUnavailable: 1
    minAvailable: null
  podLabels: {}
  podSecurityContext: {}
  priorityClassName: ''
  resources: {}
  securityContext: {}
  ssl: false
  tolerations:
    - operator: Exists
  topologySpreadConstraints: []
  updateStrategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
    type: RollingUpdate
externalIPs:
  enabled: false
externalWorkloads:
  enabled: false
extraArgs: []
extraConfig: {}
extraContainers: []
extraEnv: []
extraHostPathMounts: []
extraVolumeMounts: []
extraVolumes: []
gatewayAPI:
  enabled: false
  secretsNamespace:
    create: true
    name: cilium-secrets
    sync: true
gke:
  enabled: false
global:
  systemDefaultRegistry: ''
healthChecking: true
healthPort: 9879
highScaleIPcache:
  enabled: false
hostFirewall:
  enabled: false
hostPort:
  enabled: false
hubble:
  annotations: {}
  enabled: true
  export:
    dynamic:
      config:
        configMapName: cilium-flowlog-config
        content:
          - excludeFilters: []
            fieldMask: []
            filePath: /var/run/cilium/hubble/events.log
            includeFilters: []
            name: all
        createConfigMap: true
      enabled: false
    fileMaxBackups: 5
    fileMaxSizeMb: 10
    static:
      allowList: []
      denyList: []
      enabled: false
      fieldMask: []
      filePath: /var/run/cilium/hubble/events.log
  listenAddress: ':4244'
  metrics:
    dashboards:
      annotations: {}
      enabled: false
      label: grafana_dashboard
      labelValue: '1'
      namespace: null
    enableOpenMetrics: true
    enabled:
      - dns:query;ignoreAAAA
      - drop
      - tcp
      - http
      - flow
      - icmp
    port: 9965
    serviceAnnotations: {}
    serviceMonitor:
      annotations: {}
      enabled: false
      interval: 10s
      jobLabel: ''
      labels: {}
      metricRelabelings: null
      relabelings:
        - replacement: ${1}
          sourceLabels:
            - __meta_kubernetes_pod_node_name
          targetLabel: node
  peerService:
    clusterDomain: cluster.local
    targetPort: 4244
  preferIpv6: false
  redact:
    enabled: false
    http:
      headers:
        allow: []
        deny: []
      urlQuery: false
      userInfo: true
    kafka:
      apiKey: false
  relay:
    affinity:
      podAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                k8s-app: cilium
            topologyKey: kubernetes.io/hostname
    annotations: {}
    dialTimeout: null
    enabled: true
    extraEnv: []
    extraVolumeMounts: []
    extraVolumes: []
    gops:
      enabled: true
      port: 9893
    image:
      override: null
      pullPolicy: IfNotPresent
      repository: rancher/mirrored-cilium-hubble-relay
      tag: v1.15.1
      useDigest: false
    listenHost: ''
    listenPort: '4245'
    nodeSelector:
      kubernetes.io/os: linux
    podAnnotations: {}
    podDisruptionBudget:
      enabled: false
      maxUnavailable: 1
      minAvailable: null
    podLabels: {}
    podSecurityContext:
      fsGroup: 65532
    pprof:
      address: localhost
      enabled: false
      port: 6062
    priorityClassName: ''
    prometheus:
      enabled: false
      port: 9966
      serviceMonitor:
        annotations: {}
        enabled: false
        interval: 10s
        labels: {}
        metricRelabelings: null
        relabelings: null
    replicas: 1
    resources: {}
    retryTimeout: null
    rollOutPods: false
    securityContext:
      capabilities:
        drop:
          - ALL
      runAsGroup: 65532
      runAsNonRoot: true
      runAsUser: 65532
    service:
      nodePort: 31234
      type: ClusterIP
    sortBufferDrainTimeout: null
    sortBufferLenMax: null
    terminationGracePeriodSeconds: 1
    tls:
      client:
        cert: ''
        key: ''
      server:
        cert: ''
        enabled: false
        extraDnsNames: []
        extraIpAddresses: []
        key: ''
        mtls: false
        relayName: ui.hubble-relay.cilium.io
    tolerations: []
    topologySpreadConstraints: []
    updateStrategy:
      rollingUpdate:
        maxUnavailable: 1
      type: RollingUpdate
  skipUnknownCGroupIDs: null
  socketPath: /var/run/cilium/hubble.sock
  tls:
    auto:
      certManagerIssuerRef: {}
      certValidityDuration: 1095
      enabled: true
      method: helm
      schedule: 0 0 1 */4 *
    enabled: true
    server:
      cert: ''
      extraDnsNames: []
      extraIpAddresses: []
      key: ''
  ui:
    affinity: {}
    annotations: {}
    backend:
      extraEnv: []
      extraVolumeMounts: []
      extraVolumes: []
      image:
        override: null
        pullPolicy: IfNotPresent
        repository: rancher/mirrored-cilium-hubble-ui-backend
        tag: v0.13.0
        useDigest: false
      livenessProbe:
        enabled: false
      readinessProbe:
        enabled: false
      resources: {}
      securityContext: {}
    baseUrl: /
    enabled: true
    frontend:
      extraEnv: []
      extraVolumeMounts: []
      extraVolumes: []
      image:
        override: null
        pullPolicy: IfNotPresent
        repository: rancher/mirrored-cilium-hubble-ui
        tag: v0.13.0
        useDigest: false
      resources: {}
      securityContext: {}
      server:
        ipv6:
          enabled: true
    ingress:
      annotations: {}
      className: higress
      enabled: true
      hosts:
        - cilium.testlab.net
      labels: {}
      tls: []
    nodeSelector:
      kubernetes.io/os: linux
    podAnnotations: {}
    podDisruptionBudget:
      enabled: false
      maxUnavailable: 1
      minAvailable: null
    podLabels: {}
    priorityClassName: ''
    replicas: 1
    rollOutPods: false
    securityContext:
      fsGroup: 1001
      runAsGroup: 1001
      runAsUser: 1001
    service:
      annotations: {}
      nodePort: 31235
      type: ClusterIP
    standalone:
      enabled: false
      tls:
        certsVolume: {}
    tls:
      client:
        cert: ''
        key: ''
    tolerations: []
    topologySpreadConstraints: []
    updateStrategy:
      rollingUpdate:
        maxUnavailable: 1
      type: RollingUpdate
identityAllocationMode: crd
identityChangeGracePeriod: ''
image:
  override: null
  pullPolicy: IfNotPresent
  repository: rancher/mirrored-cilium-cilium
  tag: v1.15.1
  useDigest: false
imagePullSecrets: null
ingressController:
  default: false
  defaultSecretName: null
  defaultSecretNamespace: null
  enableProxyProtocol: false
  enabled: false
  enforceHttps: true
  ingressLBAnnotationPrefixes:
    - service.beta.kubernetes.io
    - service.kubernetes.io
    - cloud.google.com
  loadbalancerMode: dedicated
  secretsNamespace:
    create: true
    name: cilium-secrets
    sync: true
  service:
    allocateLoadBalancerNodePorts: null
    annotations: {}
    insecureNodePort: null
    labels: {}
    loadBalancerClass: null
    loadBalancerIP: null
    name: cilium-ingress
    secureNodePort: null
    type: LoadBalancer
initResources: {}
installNoConntrackIptablesRules: false
ipMasqAgent:
  enabled: false
ipam:
  ciliumNodeUpdateRate: 15s
  mode: kubernetes
  operator:
    autoCreateCiliumPodIPPools: {}
    clusterPoolIPv4MaskSize: 24
    clusterPoolIPv4PodCIDRList:
      - 10.0.0.0/8
    clusterPoolIPv6MaskSize: 120
    clusterPoolIPv6PodCIDRList:
      - fd00::/104
    externalAPILimitBurstSize: null
    externalAPILimitQPS: null
ipv4:
  enabled: true
ipv4NativeRoutingCIDR: ''
ipv6:
  enabled: false
ipv6NativeRoutingCIDR: ''
k8s: {}
k8sClientRateLimit:
  burst: null
  qps: null
k8sNetworkPolicy:
  enabled: true
k8sServiceHost: ''
k8sServicePort: ''
keepDeprecatedLabels: false
keepDeprecatedProbes: false
kubeConfigPath: ''
kubeProxyReplacementHealthzBindAddr: ''
l2NeighDiscovery:
  enabled: true
  refreshPeriod: 30s
l2announcements:
  enabled: false
l2podAnnouncements:
  enabled: false
  interface: eth0
l7Proxy: true
livenessProbe:
  failureThreshold: 10
  periodSeconds: 30
loadBalancer:
  acceleration: disabled
  l7:
    algorithm: round_robin
    backend: disabled
    ports: []
localRedirectPolicy: false
logSystemLoad: false
maglev: {}
monitor:
  enabled: false
name: cilium
nat46x64Gateway:
  enabled: false
nodePort:
  autoProtectPortRange: true
  bindProtection: true
  enableHealthCheck: true
  enableHealthCheckLoadBalancerIP: false
  enabled: false
nodeSelector:
  kubernetes.io/os: linux
nodeinit:
  affinity: {}
  annotations: {}
  bootstrapFile: /tmp/cilium-bootstrap.d/cilium-bootstrap-time
  enabled: false
  extraEnv: []
  extraVolumeMounts: []
  extraVolumes: []
  image:
    override: null
    pullPolicy: IfNotPresent
    repository: quay.io/cilium/startup-script
    tag: 62093c5c233ea914bfa26a10ba41f8780d9b737f
  nodeSelector:
    kubernetes.io/os: linux
  podAnnotations: {}
  podLabels: {}
  prestop:
    postScript: ''
    preScript: ''
  priorityClassName: ''
  resources:
    requests:
      cpu: 100m
      memory: 100Mi
  securityContext:
    capabilities:
      add:
        - SYS_MODULE
        - NET_ADMIN
        - SYS_ADMIN
        - SYS_CHROOT
        - SYS_PTRACE
    privileged: false
    seLinuxOptions:
      level: s0
      type: spc_t
  startup:
    postScript: ''
    preScript: ''
  tolerations:
    - operator: Exists
  updateStrategy:
    type: RollingUpdate
operator:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              io.cilium/app: operator
          topologyKey: kubernetes.io/hostname
  annotations: {}
  dashboards:
    annotations: {}
    enabled: false
    label: grafana_dashboard
    labelValue: '1'
    namespace: null
  dnsPolicy: ''
  enabled: true
  endpointGCInterval: 5m0s
  extraArgs: []
  extraEnv: []
  extraHostPathMounts: []
  extraVolumeMounts: []
  extraVolumes: []
  identityGCInterval: 15m0s
  identityHeartbeatTimeout: 30m0s
  image:
    override: null
    pullPolicy: IfNotPresent
    repository: rancher/mirrored-cilium-operator
    suffix: ''
    tag: v1.15.1
    useDigest: false
  nodeGCInterval: 5m0s
  nodeSelector:
    kubernetes.io/os: linux
  podAnnotations: {}
  podDisruptionBudget:
    enabled: false
    maxUnavailable: 1
    minAvailable: null
  podLabels: {}
  podSecurityContext: {}
  pprof:
    address: localhost
    enabled: false
    port: 6061
  priorityClassName: ''
  prometheus:
    enabled: true
    port: 9963
    serviceMonitor:
      annotations: {}
      enabled: false
      interval: 10s
      jobLabel: ''
      labels: {}
      metricRelabelings: null
      relabelings: null
  removeNodeTaints: true
  replicas: 2
  resources: {}
  rollOutPods: false
  securityContext: {}
  setNodeNetworkStatus: true
  setNodeTaints: false
  skipCNPStatusStartupClean: false
  skipCRDCreation: false
  tolerations:
    - operator: Exists
  topologySpreadConstraints: []
  unmanagedPodWatcher:
    intervalSeconds: 15
    restart: true
  updateStrategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 50%
    type: RollingUpdate
pmtuDiscovery:
  enabled: false
podAnnotations: {}
podLabels: {}
podSecurityContext: {}
policyCIDRMatchMode: null
policyEnforcementMode: default
portmapPlugin:
  image:
    repository: rancher/hardened-cni-plugins
    tag: v1.4.0-build20240122
pprof:
  address: localhost
  enabled: false
  port: 6060
preflight:
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              k8s-app: cilium
          topologyKey: kubernetes.io/hostname
  annotations: {}
  enabled: false
  extraEnv: []
  extraVolumeMounts: []
  extraVolumes: []
  image:
    override: null
    pullPolicy: IfNotPresent
    repository: rancher/mirrored-cilium-cilium
    tag: v1.15.1
    useDigest: false
  nodeSelector:
    kubernetes.io/os: linux
  podAnnotations: {}
  podDisruptionBudget:
    enabled: false
    maxUnavailable: 1
    minAvailable: null
  podLabels: {}
  podSecurityContext: {}
  priorityClassName: ''
  resources: {}
  securityContext: {}
  terminationGracePeriodSeconds: 1
  tofqdnsPreCache: ''
  tolerations:
    - effect: NoSchedule
      key: node.kubernetes.io/not-ready
    - effect: NoSchedule
      key: node-role.kubernetes.io/master
    - effect: NoSchedule
      key: node-role.kubernetes.io/control-plane
    - effect: NoSchedule
      key: node.cloudprovider.kubernetes.io/uninitialized
      value: 'true'
    - key: CriticalAddonsOnly
      operator: Exists
  updateStrategy:
    type: RollingUpdate
  validateCNPs: true
priorityClassName: ''
prometheus:
  controllerGroupMetrics:
    - write-cni-file
    - sync-host-ips
    - sync-lb-maps-with-k8s-services
  enabled: true
  metrics: null
  port: 9962
  serviceMonitor:
    annotations: {}
    enabled: false
    interval: 10s
    jobLabel: ''
    labels: {}
    metricRelabelings: null
    relabelings:
      - replacement: ${1}
        sourceLabels:
          - __meta_kubernetes_pod_node_name
        targetLabel: node
    trustCRDsExist: false
proxy:
  prometheus:
    enabled: true
    port: null
  sidecarImageRegex: cilium/istio_proxy
rbac:
  create: true
readinessProbe:
  failureThreshold: 3
  periodSeconds: 30
remoteNodeIdentity: true
resourceQuotas:
  cilium:
    hard:
      pods: 10k
  enabled: false
  operator:
    hard:
      pods: '15'
resources: {}
rollOutCiliumPods: false
routingMode: ''
sctp:
  enabled: false
securityContext:
  capabilities:
    applySysctlOverwrites:
      - SYS_ADMIN
      - SYS_CHROOT
      - SYS_PTRACE
    ciliumAgent:
      - CHOWN
      - KILL
      - NET_ADMIN
      - NET_RAW
      - IPC_LOCK
      - SYS_MODULE
      - SYS_ADMIN
      - SYS_RESOURCE
      - DAC_OVERRIDE
      - FOWNER
      - SETGID
      - SETUID
    cleanCiliumState:
      - NET_ADMIN
      - SYS_MODULE
      - SYS_ADMIN
      - SYS_RESOURCE
    mountCgroup:
      - SYS_ADMIN
      - SYS_CHROOT
      - SYS_PTRACE
  privileged: false
  seLinuxOptions:
    level: s0
    type: spc_t
serviceAccounts:
  cilium:
    annotations: {}
    automount: true
    create: true
    name: cilium
  clustermeshApiserver:
    annotations: {}
    automount: true
    create: true
    name: clustermesh-apiserver
  clustermeshcertgen:
    annotations: {}
    automount: true
    create: true
    name: clustermesh-apiserver-generate-certs
  envoy:
    annotations: {}
    automount: true
    create: true
    name: cilium-envoy
  etcd:
    annotations: {}
    automount: true
    create: true
    name: cilium-etcd-operator
  hubblecertgen:
    annotations: {}
    automount: true
    create: true
    name: hubble-generate-certs
  nodeinit:
    annotations: {}
    automount: true
    create: true
    enabled: false
    name: cilium-nodeinit
  operator:
    annotations: {}
    automount: true
    create: true
    name: cilium-operator
  preflight:
    annotations: {}
    automount: true
    create: true
    name: cilium-pre-flight
  relay:
    annotations: {}
    automount: false
    create: true
    name: hubble-relay
  ui:
    annotations: {}
    automount: true
    create: true
    name: hubble-ui
serviceNoBackendResponse: reject
sleepAfterInit: false
socketLB:
  enabled: false
startupProbe:
  failureThreshold: 105
  periodSeconds: 2
svcSourceRangeCheck: true
synchronizeK8sNodes: true
terminationGracePeriodSeconds: 1
tls:
  ca:
    cert: ''
    certValidityDuration: 1095
    key: ''
  caBundle:
    enabled: false
    key: ca.crt
    name: cilium-root-ca.crt
    useSecret: false
  secretsBackend: local
tolerations:
  - operator: Exists
tunnelPort: 0
tunnelProtocol: ''
updateStrategy:
  rollingUpdate:
    maxUnavailable: 2
  type: RollingUpdate
vtep:
  cidr: ''
  enabled: false
  endpoint: ''
  mac: ''
  mask: ''
waitForKubeProxy: false
wellKnownIdentities:
  enabled: false

```