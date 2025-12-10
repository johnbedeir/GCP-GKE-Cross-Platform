####################################################################################################
###                                                                                              ###
###                                   CLUSTER AUTOSCALER                                         ###
###                                                                                              ###
####################################################################################################

# GKE has native cluster autoscaler support built into the platform
# Unlike EKS, GKE does not require a separate cluster autoscaler deployment
#
# Cluster autoscaler is configured in two places:
# 1. Cluster level: cluster_autoscaling block in gke.tf (enables the feature)
# 2. Node pool level: autoscaling block in node_pool.tf (configures min/max nodes)
#
# The autoscaler automatically:
# - Scales up when pods can't be scheduled due to insufficient resources
# - Scales down when nodes are underutilized
# - Respects the min/max node counts configured in node pools
#
# Current configuration:
# - Cluster autoscaler: Enabled via cluster_autoscaling block
# - Node pool autoscaling: Configured in node_pool.tf with min/max node counts
# - Auto-repair: Enabled (automatically repairs unhealthy nodes)
# - Auto-upgrade: Enabled (automatically upgrades node versions)

