# gp3 default StorageClass (§8 raw resource). Makes gp3 the cluster default and
# removes the default annotation from the EKS-provided gp2 class so new PVCs land
# on gp3. Uses the shared EBS KMS key for encryption at rest.
resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  reclaim_policy         = "Delete"

  parameters = {
    type      = "gp3"
    encrypted = "true"
    kmsKeyId  = data.terraform_remote_state.global.outputs.kms_ebs_key_arn
  }

  depends_on = [module.eks]
}

# Unset the default-class annotation on the built-in gp2 StorageClass.
resource "kubernetes_annotations" "gp2_not_default" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"

  metadata {
    name = "gp2"
  }

  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }

  # gp2 is created by EKS, so take over the annotation.
  force = true

  depends_on = [module.eks]
}
