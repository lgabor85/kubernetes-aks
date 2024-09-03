@description('Name of the Grafana instance')
param grafana_name string = 'grafana-${aksClusterName}'

@description('Name of the action group for recommended alert rules')
param actionGroups_RecommendedAlertRules_AG_1_name string = 'RecommendedAlertRules-AG-1-${aksClusterName}'

@description('Name of the Azure Monitor workspace')
param accounts_defaultazuremonitorworkspace_weu_name string = 'defaultazuremonitorworkspace-weu-aksPoc'

@description('Name of the data collection rule for MSCI')
param dataCollectionRules_MSCI_westeurope_name string = 'dcRules_MSCI-westeurope-${aksClusterName}'

@description('Name of the metric alert for CPU Usage Percentage')
param metricAlerts_CPU_Usage_Percentage_name string = 'CPU Usage Percentage - ${aksClusterName}'

@description('Name of the data collection rule for MSProm')
param dataCollectionRules_MSProm_westeurope_name string = 'dcRules_MSProm-${aksClusterName}'

@description('Name of the data collection endpoint for MSProm')
param dataCollectionEndpoints_MSProm_westeurope_name string = 'dcEndpoints-MSProm-${aksClusterName}'

@description('Name of the metric alert for Memory Working Set Percentage')
param metricAlerts_Memory_Working_Set_Percentage_name string = 'Memory Working Set Percentage - ${aksClusterName}'

@description('Name of the Prometheus Rule Group for Node')
param prometheusRuleGroups_NodeRecordingRulesRuleGroup_name string = 'NodeRecordingRulesRuleGroup_${aksClusterName}'

@description('Name of the Prometheus Rule Group for Node for Windows')
param prometheusRuleGroups_NodeRecordingRulesRuleGroup_Win_name string = 'NodeRecordingRulesRuleGroup_Win_name_${aksClusterName}'

@description('Name of the Prometheus Rule Group for Kubernetes')
param prometheusRuleGroups_KubernetesRecordingRulesRuleGroup_name string = 'K8sRecordingRulesRuleGroup_${aksClusterName}'

@description('Name of the Prometheus Rule Group for Node and Kubernetes for Windows')
param prometheusRuleGroups_NodeAndKubernetesRecordingRulesRuleGroup_Win_name string = 'NodeAndK8sRecordingRulesRuleGroup_Win_name_${aksClusterName}'

@description('Name of the AKS cluster')
param aksClusterName string

@description('Resource ID of the subnet')
param snetId string

@description('Resource ID of the Log Analytics workspace')
param workspaceId string

@description('Resource ID of the user assigned identity')
param userAssignedIdentities string

@description('Public key content for SSH access')
param publicKeyContent string

@description('Object IDs of the admin group')
param adminGroupObjectIDs string

@description('Tenant ID of the Azure AD')
param tenantID string

@description('Number of nodes in the AKS cluster')
param nodeCount int

@description('Location of the AKS cluster')
param location string

@description('Outbound type for the AKS cluster. Possible values are loadBalancer and userAssignedNatGateway')
param outboundType string

resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-01-01' = {
  name: aksClusterName
  location: location
  tags: {
    Application: 'aksPoc'
    Service: 'aksCluster'
    Owner: 'engineering'
    Department: 'development'
    OTAP: 'test'
  }
  sku: {
    name: 'Basic'
    tier: 'Free'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentities}': {}
    }
  }
  properties: {
    kubernetesVersion: '1.29.7'
    dnsPrefix: '${aksClusterName}-${location}'
    agentPoolProfiles: [
      {
        name: 'nodepool1'
        count: nodeCount
        vmSize: 'Standard_DS2_v2'
        osDiskSizeGB: 128
        osDiskType: 'Managed'
        kubeletDiskType: 'OS'
        vnetSubnetID: snetId
        maxPods: 30
        type: 'VirtualMachineScaleSets'
        enableAutoScaling: false
        powerState: {
          code: 'Running'
        }
        orchestratorVersion: '1.29.7'
        enableNodePublicIP: false
        mode: 'System'
        enableEncryptionAtHost: false
        enableUltraSSD: false
        osType: 'Linux'
        osSKU: 'Ubuntu'
        upgradeSettings: {
          upgradeChannel: 'None'
        }
        enableFIPS: false
        securityProfile: {
          sshAccess: 'LocalUser'
        }
      }
    ]
    linuxProfile: {
      adminUsername: 'azureuser'
      ssh: {
        publicKeys: [
          {
            keyData: publicKeyContent
          }
        ]
      }
    }
    servicePrincipalProfile: {
      clientId: 'msi'
    }
    addonProfiles: {
      azurepolicy: {
        enabled: true
      }
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: workspaceId
          useAADAuth: 'true'
        }
      }
    }
    nodeResourceGroup: 'MC_rg-aks-demo_${aksClusterName}_${location}'
    enableRBAC: true
    supportPlan: 'KubernetesOfficial'
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'calico'
      networkDataplane: 'azure'
      loadBalancerSku: 'Standard'
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
      outboundType: outboundType
      serviceCidrs: [
        '10.0.0.0/16'
      ]
      ipFamilies: [
        'IPv4'
      ]
    }
    aadProfile: {
      managed: true
      adminGroupObjectIDs: [
        adminGroupObjectIDs
      ]
      enableAzureRBAC: false
      tenantID: tenantID
    }
    autoUpgradeProfile: {
      nodeOSUpgradeChannel: 'none'
    }
    disableLocalAccounts: false
    securityProfile: {}
    storageProfile: {
      diskCSIDriver: {
        enabled: true
        version: 'v1'
      }
      fileCSIDriver: {
        enabled: true
      }
      snapshotController: {
        enabled: true
      }
    }
    oidcIssuerProfile: {
      enabled: false
    }
    workloadAutoScalerProfile: {}
    metricsProfile: {
      costAnalysis: {
        enabled: false
      }
    }
  }
}

resource actionGroups_RecommendedAlertRules_AG_1_name_resource 'microsoft.insights/actionGroups@2023-01-01' = {
  name: actionGroups_RecommendedAlertRules_AG_1_name
  location: 'Global'
  properties: {
    groupShortName: 'recalert1'
    enabled: true
    emailReceivers: [
      {
        name: 'Email_-EmailAction-'
        emailAddress: 'my@email.com'
        useCommonAlertSchema: true
      }
    ]
    smsReceivers: []
    webhookReceivers: []
    eventHubReceivers: []
    itsmReceivers: []
    azureAppPushReceivers: []
    automationRunbookReceivers: []
    voiceReceivers: []
    logicAppReceivers: []
    azureFunctionReceivers: []
    armRoleReceivers: []
  }
}

resource dataCollectionEndpoints_MSProm_westeurope_name_resource 'Microsoft.Insights/dataCollectionEndpoints@2022-06-01' = {
  name: dataCollectionEndpoints_MSProm_westeurope_name
  location: location
  kind: 'Linux'
  properties: {
    immutableId: 'dce-6647e147a02d419f900ebad2875174ae'
    configurationAccess: {}
    logsIngestion: {}
    metricsIngestion: {}
    networkAcls: {
      publicNetworkAccess: 'Enabled'
    }
  }
}

resource dataCollectionRules_MSCI_westeurope_name_resource 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: dataCollectionRules_MSCI_westeurope_name
  location: location
  tags: {
    Application: 'aksPoc'
    Department: 'engineering'
    OTAP: 'test'
    Owner: 'development'
    Service: 'aksCluster'
  }
  kind: 'Linux'
  properties: {
    dataSources: {
      syslog: []
      extensions: [
        {
          streams: [
            'Microsoft-ContainerInsights-Group-Default'
          ]
          extensionName: 'ContainerInsights'
          extensionSettings: {}
          name: 'ContainerInsightsExtension'
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: workspaceId
          name: 'ciworkspace'
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-ContainerInsights-Group-Default'
        ]
        destinations: [
          'ciworkspace'
        ]
      }
    ]
  }
}

resource accounts_defaultazuremonitorworkspace_weu_name_resource 'microsoft.monitor/accounts@2023-04-03' = {
  name: accounts_defaultazuremonitorworkspace_weu_name
  location: location
  properties: {}
}

resource prometheusRuleGroups_KubernetesRecordingRulesRuleGroup_name_resource 'Microsoft.AlertsManagement/prometheusRuleGroups@2023-03-01' = {
  name: prometheusRuleGroups_KubernetesRecordingRulesRuleGroup_name
  location: location
  properties: {
    enabled: true
    description: 'Kubernetes Recording Rules RuleGroup'
    clusterName: aksClusterName
    scopes: [
      accounts_defaultazuremonitorworkspace_weu_name_resource.id
    ]
    rules: [
      {
        record: 'node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate'
        expression: 'sum by (cluster, namespace, pod, container) (  irate(container_cpu_usage_seconds_total{job="cadvisor", image!=""}[5m])) * on (cluster, namespace, pod) group_left(node) topk by (cluster, namespace, pod) (  1, max by(cluster, namespace, pod, node) (kube_pod_info{node!=""}))'
      }
      {
        record: 'node_namespace_pod_container:container_memory_working_set_bytes'
        expression: 'container_memory_working_set_bytes{job="cadvisor", image!=""}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1,  max by(namespace, pod, node) (kube_pod_info{node!=""}))'
      }
      {
        record: 'node_namespace_pod_container:container_memory_rss'
        expression: 'container_memory_rss{job="cadvisor", image!=""}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1,  max by(namespace, pod, node) (kube_pod_info{node!=""}))'
      }
      {
        record: 'node_namespace_pod_container:container_memory_cache'
        expression: 'container_memory_cache{job="cadvisor", image!=""}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1,  max by(namespace, pod, node) (kube_pod_info{node!=""}))'
      }
      {
        record: 'node_namespace_pod_container:container_memory_swap'
        expression: 'container_memory_swap{job="cadvisor", image!=""}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1,  max by(namespace, pod, node) (kube_pod_info{node!=""}))'
      }
      {
        record: 'cluster:namespace:pod_memory:active:kube_pod_container_resource_requests'
        expression: 'kube_pod_container_resource_requests{resource="memory",job="kube-state-metrics"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) (  (kube_pod_status_phase{phase=~"Pending|Running"} == 1))'
      }
      {
        record: 'namespace_memory:kube_pod_container_resource_requests:sum'
        expression: 'sum by (namespace, cluster) (    sum by (namespace, pod, cluster) (        max by (namespace, pod, container, cluster) (          kube_pod_container_resource_requests{resource="memory",job="kube-state-metrics"}        ) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (          kube_pod_status_phase{phase=~"Pending|Running"} == 1        )    ))'
      }
      {
        record: 'cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests'
        expression: 'kube_pod_container_resource_requests{resource="cpu",job="kube-state-metrics"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) (  (kube_pod_status_phase{phase=~"Pending|Running"} == 1))'
      }
      {
        record: 'namespace_cpu:kube_pod_container_resource_requests:sum'
        expression: 'sum by (namespace, cluster) (    sum by (namespace, pod, cluster) (        max by (namespace, pod, container, cluster) (          kube_pod_container_resource_requests{resource="cpu",job="kube-state-metrics"}        ) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (          kube_pod_status_phase{phase=~"Pending|Running"} == 1        )    ))'
      }
      {
        record: 'cluster:namespace:pod_memory:active:kube_pod_container_resource_limits'
        expression: 'kube_pod_container_resource_limits{resource="memory",job="kube-state-metrics"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) (  (kube_pod_status_phase{phase=~"Pending|Running"} == 1))'
      }
      {
        record: 'namespace_memory:kube_pod_container_resource_limits:sum'
        expression: 'sum by (namespace, cluster) (    sum by (namespace, pod, cluster) (        max by (namespace, pod, container, cluster) (          kube_pod_container_resource_limits{resource="memory",job="kube-state-metrics"}        ) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (          kube_pod_status_phase{phase=~"Pending|Running"} == 1        )    ))'
      }
      {
        record: 'cluster:namespace:pod_cpu:active:kube_pod_container_resource_limits'
        expression: 'kube_pod_container_resource_limits{resource="cpu",job="kube-state-metrics"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) ( (kube_pod_status_phase{phase=~"Pending|Running"} == 1) )'
      }
      {
        record: 'namespace_cpu:kube_pod_container_resource_limits:sum'
        expression: 'sum by (namespace, cluster) (    sum by (namespace, pod, cluster) (        max by (namespace, pod, container, cluster) (          kube_pod_container_resource_limits{resource="cpu",job="kube-state-metrics"}        ) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (          kube_pod_status_phase{phase=~"Pending|Running"} == 1        )    ))'
      }
      {
        record: 'namespace_workload_pod:kube_pod_owner:relabel'
        expression: 'max by (cluster, namespace, workload, pod) (  label_replace(    label_replace(      kube_pod_owner{job="kube-state-metrics", owner_kind="ReplicaSet"},      "replicaset", "$1", "owner_name", "(.*)"    ) * on(replicaset, namespace) group_left(owner_name) topk by(replicaset, namespace) (      1, max by (replicaset, namespace, owner_name) (        kube_replicaset_owner{job="kube-state-metrics"}      )    ),    "workload", "$1", "owner_name", "(.*)"  ))'
        labels: {
          workload_type: 'deployment'
        }
      }
      {
        record: 'namespace_workload_pod:kube_pod_owner:relabel'
        expression: 'max by (cluster, namespace, workload, pod) (  label_replace(    kube_pod_owner{job="kube-state-metrics", owner_kind="DaemonSet"},    "workload", "$1", "owner_name", "(.*)"  ))'
        labels: {
          workload_type: 'daemonset'
        }
      }
      {
        record: 'namespace_workload_pod:kube_pod_owner:relabel'
        expression: 'max by (cluster, namespace, workload, pod) (  label_replace(    kube_pod_owner{job="kube-state-metrics", owner_kind="StatefulSet"},    "workload", "$1", "owner_name", "(.*)"  ))'
        labels: {
          workload_type: 'statefulset'
        }
      }
      {
        record: 'namespace_workload_pod:kube_pod_owner:relabel'
        expression: 'max by (cluster, namespace, workload, pod) (  label_replace(    kube_pod_owner{job="kube-state-metrics", owner_kind="Job"},    "workload", "$1", "owner_name", "(.*)"  ))'
        labels: {
          workload_type: 'job'
        }
      }
      {
        record: ':node_memory_MemAvailable_bytes:sum'
        expression: 'sum(  node_memory_MemAvailable_bytes{job="node"} or  (    node_memory_Buffers_bytes{job="node"} +    node_memory_Cached_bytes{job="node"} +    node_memory_MemFree_bytes{job="node"} +    node_memory_Slab_bytes{job="node"}  )) by (cluster)'
      }
      {
        record: 'cluster:node_cpu:ratio_rate5m'
        expression: 'sum(rate(node_cpu_seconds_total{job="node",mode!="idle",mode!="iowait",mode!="steal"}[5m])) by (cluster) /count(sum(node_cpu_seconds_total{job="node"}) by (cluster, instance, cpu)) by (cluster)'
      }
    ]
    interval: 'PT1M'
  }
}

resource prometheusRuleGroups_NodeAndKubernetesRecordingRulesRuleGroup_Win_name_resource 'Microsoft.AlertsManagement/prometheusRuleGroups@2023-03-01' = {
  name: prometheusRuleGroups_NodeAndKubernetesRecordingRulesRuleGroup_Win_name
  location: location
  properties: {
    enabled: false
    description: 'Node and Kubernetes Recording Rules RuleGroup for Windows'
    clusterName: aksClusterName
    scopes: [
      accounts_defaultazuremonitorworkspace_weu_name_resource.id
    ]
    rules: [
      {
        record: 'node:windows_node_filesystem_usage:'
        expression: 'max by (instance,volume)((windows_logical_disk_size_bytes{job="windows-exporter"} - windows_logical_disk_free_bytes{job="windows-exporter"}) / windows_logical_disk_size_bytes{job="windows-exporter"})'
      }
      {
        record: 'node:windows_node_filesystem_avail:'
        expression: 'max by (instance, volume) (windows_logical_disk_free_bytes{job="windows-exporter"} / windows_logical_disk_size_bytes{job="windows-exporter"})'
      }
      {
        record: ':windows_node_net_utilisation:sum_irate'
        expression: 'sum(irate(windows_net_bytes_total{job="windows-exporter"}[5m]))'
      }
      {
        record: 'node:windows_node_net_utilisation:sum_irate'
        expression: 'sum by (instance) ((irate(windows_net_bytes_total{job="windows-exporter"}[5m])))'
      }
      {
        record: ':windows_node_net_saturation:sum_irate'
        expression: 'sum(irate(windows_net_packets_received_discarded_total{job="windows-exporter"}[5m])) + sum(irate(windows_net_packets_outbound_discarded_total{job="windows-exporter"}[5m]))'
      }
      {
        record: 'node:windows_node_net_saturation:sum_irate'
        expression: 'sum by (instance) ((irate(windows_net_packets_received_discarded_total{job="windows-exporter"}[5m]) + irate(windows_net_packets_outbound_discarded_total{job="windows-exporter"}[5m])))'
      }
      {
        record: 'windows_pod_container_available'
        expression: 'windows_container_available{job="windows-exporter", container_id != ""} * on(container_id) group_left(container, pod, namespace) max(kube_pod_container_info{job="kube-state-metrics", container_id != ""}) by(container, container_id, pod, namespace)'
      }
      {
        record: 'windows_container_total_runtime'
        expression: 'windows_container_cpu_usage_seconds_total{job="windows-exporter", container_id != ""} * on(container_id) group_left(container, pod, namespace) max(kube_pod_container_info{job="kube-state-metrics", container_id != ""}) by(container, container_id, pod, namespace)'
      }
      {
        record: 'windows_container_memory_usage'
        expression: 'windows_container_memory_usage_commit_bytes{job="windows-exporter", container_id != ""} * on(container_id) group_left(container, pod, namespace) max(kube_pod_container_info{job="kube-state-metrics", container_id != ""}) by(container, container_id, pod, namespace)'
      }
      {
        record: 'windows_container_private_working_set_usage'
        expression: 'windows_container_memory_usage_private_working_set_bytes{job="windows-exporter", container_id != ""} * on(container_id) group_left(container, pod, namespace) max(kube_pod_container_info{job="kube-state-metrics", container_id != ""}) by(container, container_id, pod, namespace)'
      }
      {
        record: 'windows_container_network_received_bytes_total'
        expression: 'windows_container_network_receive_bytes_total{job="windows-exporter", container_id != ""} * on(container_id) group_left(container, pod, namespace) max(kube_pod_container_info{job="kube-state-metrics", container_id != ""}) by(container, container_id, pod, namespace)'
      }
      {
        record: 'windows_container_network_transmitted_bytes_total'
        expression: 'windows_container_network_transmit_bytes_total{job="windows-exporter", container_id != ""} * on(container_id) group_left(container, pod, namespace) max(kube_pod_container_info{job="kube-state-metrics", container_id != ""}) by(container, container_id, pod, namespace)'
      }
      {
        record: 'kube_pod_windows_container_resource_memory_request'
        expression: 'max by (namespace, pod, container) (kube_pod_container_resource_requests{resource="memory",job="kube-state-metrics"}) * on(container,pod,namespace) (windows_pod_container_available)'
      }
      {
        record: 'kube_pod_windows_container_resource_memory_limit'
        expression: 'kube_pod_container_resource_limits{resource="memory",job="kube-state-metrics"} * on(container,pod,namespace) (windows_pod_container_available)'
      }
      {
        record: 'kube_pod_windows_container_resource_cpu_cores_request'
        expression: 'max by (namespace, pod, container) ( kube_pod_container_resource_requests{resource="cpu",job="kube-state-metrics"}) * on(container,pod,namespace) (windows_pod_container_available)'
      }
      {
        record: 'kube_pod_windows_container_resource_cpu_cores_limit'
        expression: 'kube_pod_container_resource_limits{resource="cpu",job="kube-state-metrics"} * on(container,pod,namespace) (windows_pod_container_available)'
      }
      {
        record: 'namespace_pod_container:windows_container_cpu_usage_seconds_total:sum_rate'
        expression: 'sum by (namespace, pod, container) (rate(windows_container_total_runtime{}[5m]))'
      }
    ]
    interval: 'PT1M'
  }
}

resource prometheusRuleGroups_NodeRecordingRulesRuleGroup_name_resource 'Microsoft.AlertsManagement/prometheusRuleGroups@2023-03-01' = {
  name: prometheusRuleGroups_NodeRecordingRulesRuleGroup_name
  location: location
  properties: {
    enabled: true
    description: 'Node Recording Rules RuleGroup'
    clusterName: aksClusterName
    scopes: [
      accounts_defaultazuremonitorworkspace_weu_name_resource.id
    ]
    rules: [
      {
        record: 'instance:node_num_cpu:sum'
        expression: 'count without (cpu, mode) (  node_cpu_seconds_total{job="node",mode="idle"})'
      }
      {
        record: 'instance:node_cpu_utilisation:rate5m'
        expression: '1 - avg without (cpu) (  sum without (mode) (rate(node_cpu_seconds_total{job="node", mode=~"idle|iowait|steal"}[5m])))'
      }
      {
        record: 'instance:node_load1_per_cpu:ratio'
        expression: '(  node_load1{job="node"}/  instance:node_num_cpu:sum{job="node"})'
      }
      {
        record: 'instance:node_memory_utilisation:ratio'
        expression: '1 - (  (    node_memory_MemAvailable_bytes{job="node"}    or    (      node_memory_Buffers_bytes{job="node"}      +      node_memory_Cached_bytes{job="node"}      +      node_memory_MemFree_bytes{job="node"}      +      node_memory_Slab_bytes{job="node"}    )  )/  node_memory_MemTotal_bytes{job="node"})'
      }
      {
        record: 'instance:node_vmstat_pgmajfault:rate5m'
        expression: 'rate(node_vmstat_pgmajfault{job="node"}[5m])'
      }
      {
        record: 'instance_device:node_disk_io_time_seconds:rate5m'
        expression: 'rate(node_disk_io_time_seconds_total{job="node", device!=""}[5m])'
      }
      {
        record: 'instance_device:node_disk_io_time_weighted_seconds:rate5m'
        expression: 'rate(node_disk_io_time_weighted_seconds_total{job="node", device!=""}[5m])'
      }
      {
        record: 'instance:node_network_receive_bytes_excluding_lo:rate5m'
        expression: 'sum without (device) (  rate(node_network_receive_bytes_total{job="node", device!="lo"}[5m]))'
      }
      {
        record: 'instance:node_network_transmit_bytes_excluding_lo:rate5m'
        expression: 'sum without (device) (  rate(node_network_transmit_bytes_total{job="node", device!="lo"}[5m]))'
      }
      {
        record: 'instance:node_network_receive_drop_excluding_lo:rate5m'
        expression: 'sum without (device) (  rate(node_network_receive_drop_total{job="node", device!="lo"}[5m]))'
      }
      {
        record: 'instance:node_network_transmit_drop_excluding_lo:rate5m'
        expression: 'sum without (device) (  rate(node_network_transmit_drop_total{job="node", device!="lo"}[5m]))'
      }
    ]
    interval: 'PT1M'
  }
}

resource prometheusRuleGroups_NodeRecordingRulesRuleGroup_Win_name_resource 'Microsoft.AlertsManagement/prometheusRuleGroups@2023-03-01' = {
  name: prometheusRuleGroups_NodeRecordingRulesRuleGroup_Win_name
  location: location
  properties: {
    enabled: false
    description: 'Node Recording Rules RuleGroup for Windows'
    clusterName: aksClusterName
    scopes: [
      accounts_defaultazuremonitorworkspace_weu_name_resource.id
    ]
    rules: [
      {
        record: 'node:windows_node:sum'
        expression: 'count (windows_system_system_up_time{job="windows-exporter"})'
      }
      {
        record: 'node:windows_node_num_cpu:sum'
        expression: 'count by (instance) (sum by (instance, core) (windows_cpu_time_total{job="windows-exporter"}))'
      }
      {
        record: ':windows_node_cpu_utilisation:avg5m'
        expression: '1 - avg(rate(windows_cpu_time_total{job="windows-exporter",mode="idle"}[5m]))'
      }
      {
        record: 'node:windows_node_cpu_utilisation:avg5m'
        expression: '1 - avg by (instance) (rate(windows_cpu_time_total{job="windows-exporter",mode="idle"}[5m]))'
      }
      {
        record: ':windows_node_memory_utilisation:'
        expression: '1 -sum(windows_memory_available_bytes{job="windows-exporter"})/sum(windows_os_visible_memory_bytes{job="windows-exporter"})'
      }
      {
        record: ':windows_node_memory_MemFreeCached_bytes:sum'
        expression: 'sum(windows_memory_available_bytes{job="windows-exporter"} + windows_memory_cache_bytes{job="windows-exporter"})'
      }
      {
        record: 'node:windows_node_memory_totalCached_bytes:sum'
        expression: '(windows_memory_cache_bytes{job="windows-exporter"} + windows_memory_modified_page_list_bytes{job="windows-exporter"} + windows_memory_standby_cache_core_bytes{job="windows-exporter"} + windows_memory_standby_cache_normal_priority_bytes{job="windows-exporter"} + windows_memory_standby_cache_reserve_bytes{job="windows-exporter"})'
      }
      {
        record: ':windows_node_memory_MemTotal_bytes:sum'
        expression: 'sum(windows_os_visible_memory_bytes{job="windows-exporter"})'
      }
      {
        record: 'node:windows_node_memory_bytes_available:sum'
        expression: 'sum by (instance) ((windows_memory_available_bytes{job="windows-exporter"}))'
      }
      {
        record: 'node:windows_node_memory_bytes_total:sum'
        expression: 'sum by (instance) (windows_os_visible_memory_bytes{job="windows-exporter"})'
      }
      {
        record: 'node:windows_node_memory_utilisation:ratio'
        expression: '(node:windows_node_memory_bytes_total:sum - node:windows_node_memory_bytes_available:sum) / scalar(sum(node:windows_node_memory_bytes_total:sum))'
      }
      {
        record: 'node:windows_node_memory_utilisation:'
        expression: '1 - (node:windows_node_memory_bytes_available:sum / node:windows_node_memory_bytes_total:sum)'
      }
      {
        record: 'node:windows_node_memory_swap_io_pages:irate'
        expression: 'irate(windows_memory_swap_page_operations_total{job="windows-exporter"}[5m])'
      }
      {
        record: ':windows_node_disk_utilisation:avg_irate'
        expression: 'avg(irate(windows_logical_disk_read_seconds_total{job="windows-exporter"}[5m]) + irate(windows_logical_disk_write_seconds_total{job="windows-exporter"}[5m]))'
      }
      {
        record: 'node:windows_node_disk_utilisation:avg_irate'
        expression: 'avg by (instance) ((irate(windows_logical_disk_read_seconds_total{job="windows-exporter"}[5m]) + irate(windows_logical_disk_write_seconds_total{job="windows-exporter"}[5m])))'
      }
    ]
    interval: 'PT1M'
  }
}

resource aksClusterName_nodepool1 'Microsoft.ContainerService/managedClusters/agentPools@2023-01-01' = {
  parent: aksCluster
  name: 'nodepool1'
  properties: {
    count: 1
    vmSize: 'Standard_DS2_v2'
    osDiskSizeGB: 128
    osDiskType: 'Managed'
    kubeletDiskType: 'OS'
    vnetSubnetID: snetId
    maxPods: 30
    type: 'VirtualMachineScaleSets'
    enableAutoScaling: false
    powerState: {
      code: 'Running'
    }
    orchestratorVersion: '1.29.7'
    enableNodePublicIP: false
    mode: 'System'
    enableEncryptionAtHost: false
    enableUltraSSD: false
    osType: 'Linux'
    osSKU: 'Ubuntu'
    upgradeSettings: {}
    enableFIPS: false
    securityProfile: {
      sshAccess: 'LocalUser'
    }
  }
}

resource grafana_name_resource 'microsoft.dashboard/grafana@2022-08-01' = {
  name: grafana_name
  location: location
  sku: {
    name: 'Standard'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    provisioningState: 'Succeeded'
    zoneRedundancy: 'Disabled'
    publicNetworkAccess: 'Enabled'
    autoGeneratedDomainNameLabelScope: 'TenantReuse'
    apiKey: 'Disabled'
    deterministicOutboundIP: 'Disabled'
    grafanaIntegrations: {
      azureMonitorWorkspaceIntegrations: [
        {
          azureMonitorWorkspaceResourceId: accounts_defaultazuremonitorworkspace_weu_name_resource.id
        }
      ]
    }
  }
}

resource dataCollectionRules_MSProm_westeurope_name_resource 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: dataCollectionRules_MSProm_westeurope_name
  location: location
  kind: 'Linux'
  properties: {
    dataCollectionEndpointId: dataCollectionEndpoints_MSProm_westeurope_name_resource.id
    dataSources: {
      prometheusForwarder: [
        {
          streams: [
            'Microsoft-PrometheusMetrics'
          ]
          labelIncludeFilter: {}
          name: 'PrometheusDataSource'
        }
      ]
    }
    destinations: {
      monitoringAccounts: [
        {
          accountResourceId: accounts_defaultazuremonitorworkspace_weu_name_resource.id
          name: 'MonitoringAccount1'
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-PrometheusMetrics'
        ]
        destinations: [
          'MonitoringAccount1'
        ]
      }
    ]
  }
}

resource metricAlerts_CPU_Usage_Percentage_name_resource 'microsoft.insights/metricAlerts@2018-03-01' = {
  name: metricAlerts_CPU_Usage_Percentage_name
  location: 'Global'
  properties: {
    severity: 3
    enabled: true
    scopes: [
      aksCluster.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          threshold: 95
          name: 'Metric1'
          metricNamespace: 'Microsoft.ContainerService/managedClusters'
          metricName: 'node_cpu_usage_percentage'
          operator: 'GreaterThan'
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
    }
    targetResourceType: 'Microsoft.ContainerService/managedClusters'
    actions: [
      {
        actionGroupId: actionGroups_RecommendedAlertRules_AG_1_name_resource.id
        webHookProperties: {}
      }
    ]
  }
}

resource metricAlerts_Memory_Working_Set_Percentage_name_resource 'microsoft.insights/metricAlerts@2018-03-01' = {
  name: metricAlerts_Memory_Working_Set_Percentage_name
  location: 'Global'
  properties: {
    severity: 3
    enabled: true
    scopes: [
      aksCluster.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          threshold: 100
          name: 'Metric1'
          metricNamespace: 'Microsoft.ContainerService/managedClusters'
          metricName: 'node_memory_working_set_percentage'
          operator: 'GreaterThan'
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
    }
    targetResourceType: 'Microsoft.ContainerService/managedClusters'
    actions: [
      {
        actionGroupId: actionGroups_RecommendedAlertRules_AG_1_name_resource.id
        webHookProperties: {}
      }
    ]
  }
}
