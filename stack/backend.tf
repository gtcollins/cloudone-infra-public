# Partial backend: the settings (bucket, key, region...) come from
# envs/<env>/backend.hcl, passed by ./scripts/tf.sh <env> init.
terraform {
  backend "s3" {}
}
