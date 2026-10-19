# Thin wrapper around terraform-aws-modules/eks/aws v21.
# NOTE: v21 renamed inputs — use `name`, `kubernetes_version`, `addons`,
# `endpoint_public_access` (NOT cluster_name / cluster_version / cluster_addons).
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.name
  kubernetes_version = var.kubernetes_version

  # Access: API-only auth (access entries). Creator-admin is caller-dependent, so
  # it is disabled where applies run from multiple identities (see the variable);
  # those clusters list every admin in cluster_admin_principal_arns instead.
  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

  # Endpoint: public but restricted to known CIDRs, plus private for in-VPC traffic.
  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs
  endpoint_private_access      = true

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.control_plane_subnet_ids

  # Envelope-encrypt Kubernetes secrets with the shared KMS key.
  encryption_config = {
    provider_key_arn = var.kms_key_arn
    resources        = ["secrets"]
  }

  # All control-plane log types on.
  enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Core addons. vpc-cni and the pod-identity agent must come up before nodes
  # (before_compute) so networking + pod identity work from first boot.
  # aws-ebs-csi-driver uses its dedicated IRSA role from modules/irsa.
  addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
    eks-pod-identity-agent = {
      before_compute = true
    }
    aws-ebs-csi-driver = {
      service_account_role_arn = var.ebs_csi_role_arn
    }
  }

  # Small, fixed bootstrap node group. It only runs bootstrap-critical pods
  # (CoreDNS, Karpenter, ArgoCD) before Karpenter provisions the rest.
  eks_managed_node_groups = {
    bootstrap = {
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
      subnet_ids     = var.subnet_ids
    }
  }

  # Namespace-scoped access entries for the app teams. In-cluster RBAC
  # (RoleBindings) is owned by GitOps; here we only grant cluster access.
  # Each entry is created only when its role ARN is set — the principal must be
  # an EXISTING IAM role in this cluster's account, or EKS rejects it.
  access_entries = merge(
    var.dev_team_role_arn != "" ? {
      dev_team = {
        principal_arn = var.dev_team_role_arn
        policy_associations = {
          edit = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
            access_scope = {
              type       = "namespace"
              namespaces = ["development"]
            }
          }
        }
      }
    } : {},
    var.staging_team_role_arn != "" ? {
      staging_team = {
        principal_arn = var.staging_team_role_arn
        policy_associations = {
          edit = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
            access_scope = {
              type       = "namespace"
              namespaces = ["staging"]
            }
          }
        }
      }
    } : {},
    # Cluster-admin access entries for platform engineers. For IAM Identity
    # Center (SSO) principals, use the PATH-LESS role ARN
    # (arn:…:role/AWSReservedSSO_<name>_<hash>) — EKS strips the sso path, so the
    # full-path form causes a perpetual diff.
    { for arn in var.cluster_admin_principal_arns : arn => {
      principal_arn = arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    } },
  )

  tags = var.tags
}
