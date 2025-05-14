cd infra  # wherever your files are

# Load your environment variables
set -o allexport
source ../.env
set +o allexport

# Confirm in shell
echo $TF_VAR_GCP_PROJECT_ID   # should output your project ID

# Then run Terraform in the same shell
terraform init
# terraform apply
terraform plan