# Service Account Setup Guide

## 🎯 **Purpose**

This guide helps you set up the dedicated `terraform-dataops` service account for secure infrastructure management. Use this when:
- Setting up a new development environment
- Onboarding team members
- Recovering from credential issues
- Setting up CI/CD pipelines

## 🔐 **Prerequisites**

- GCP project access (`manish-sandpit`)
- `gcloud` CLI installed and authenticated
- Appropriate IAM permissions to create service accounts

## 📋 **Step-by-Step Setup**

### **Step 1: Verify Project Access**

```bash
# Authenticate with your personal account first
gcloud auth login

# Set the correct project
gcloud config set project manish-sandpit

# Verify access
gcloud projects list --filter="projectId:manish-sandpit"
```

**Expected Output:**
```
PROJECT_ID      NAME            PROJECT_NUMBER
manish-sandpit  manish-sandpit  98704470182
```

### **Step 2: Create Service Account (if not exists)**

```bash
# Check if service account already exists
gcloud iam service-accounts list --filter="email:terraform-dataops@manish-sandpit.iam.gserviceaccount.com"

# If it doesn't exist, create it
gcloud iam service-accounts create terraform-dataops \
  --display-name="Terraform DataOps Service Account" \
  --description="Service account for managing DataOps infrastructure with least privileges" \
  --project=manish-sandpit
```

### **Step 3: Assign Required IAM Roles**

```bash
# Core roles for terraform operations
ROLES=(
  "roles/storage.admin"
  "roles/pubsub.admin"
  "roles/bigquery.admin"
  "roles/dataflow.admin"
  "roles/iam.serviceAccountAdmin"
  "roles/resourcemanager.projectIamAdmin"
  "roles/monitoring.admin"
  "roles/logging.admin"
)

# Assign each role
for ROLE in "${ROLES[@]}"; do
  echo "Assigning $ROLE..."
  gcloud projects add-iam-policy-binding manish-sandpit \
    --member="serviceAccount:terraform-dataops@manish-sandpit.iam.gserviceaccount.com" \
    --role="$ROLE"
done
```

### **Step 4: Create Secure Directory Structure**

```bash
# Create secure directory for credentials
mkdir -p ~/.gcp/credentials

# Set restrictive permissions (owner read/write only)
chmod 700 ~/.gcp/credentials
```

### **Step 5: Generate Service Account Key**

```bash
# Generate new service account key
gcloud iam service-accounts keys create ~/.gcp/credentials/terraform-dataops-key.json \
  --iam-account=terraform-dataops@manish-sandpit.iam.gserviceaccount.com

# Secure the key file
chmod 600 ~/.gcp/credentials/terraform-dataops-key.json

# Verify file permissions
ls -la ~/.gcp/credentials/
```

**Expected Output:**
```
total 8
drwx------  3 username  staff    96 Oct  7 10:25 .
drwxr-xr-x  3 username  staff    96 Oct  7 10:25 ..
-rw-------  1 username  staff  2370 Oct  7 10:25 terraform-dataops-key.json
```

### **Step 6: Test Service Account Authentication**

```bash
# Set environment variable
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.gcp/credentials/terraform-dataops-key.json"

# Test authentication
gcloud auth list

# Test service account access
gcloud projects list --filter="projectId:manish-sandpit"
```

### **Step 7: Configure Terraform**

```bash
# Navigate to infrastructure directory
cd infrastructure

# Initialize terraform with service account
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.gcp/credentials/terraform-dataops-key.json"
terraform init

# Test terraform plan
terraform plan
```

## 🚀 **Daily Usage**

### **Option 1: Using Helper Script (Recommended)**

```bash
cd infrastructure

# Use the provided helper script
./terraform-sa.sh init
./terraform-sa.sh plan
./terraform-sa.sh apply
./terraform-sa.sh destroy
```

### **Option 2: Manual Environment Variable**

```bash
# Set environment variable (in your shell profile for persistence)
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.gcp/credentials/terraform-dataops-key.json"

# Then use terraform normally
terraform plan
terraform apply
```

### **Option 3: Shell Profile Integration**

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
# DataOps Service Account
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.gcp/credentials/terraform-dataops-key.json"

# Alias for convenience
alias tf-dataops='terraform'
alias tf-sa='export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.gcp/credentials/terraform-dataops-key.json"'
```

## 🔍 **Verification & Troubleshooting**

### **Verify Service Account Permissions**

```bash
# Check assigned roles
gcloud projects get-iam-policy manish-sandpit \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:terraform-dataops@manish-sandpit.iam.gserviceaccount.com"
```

**Expected Roles:**
```
ROLE
roles/bigquery.admin
roles/dataflow.admin
roles/iam.serviceAccountAdmin
roles/logging.admin
roles/monitoring.admin
roles/pubsub.admin
roles/resourcemanager.projectIamAdmin
roles/storage.admin
```

### **Test Specific Service Access**

```bash
# Test BigQuery access
bq ls --project_id=manish-sandpit

# Test Storage access
gsutil ls gs://

# Test Pub/Sub access
gcloud pubsub topics list --project=manish-sandpit
```

### **Common Issues & Solutions**

#### **Issue: Permission Denied**
```bash
# Check if credentials are properly set
echo $GOOGLE_APPLICATION_CREDENTIALS

# Verify file exists and is readable
ls -la $GOOGLE_APPLICATION_CREDENTIALS

# Re-authenticate if needed
gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS
```

#### **Issue: File Not Found**
```bash
# Check if credentials file exists
ls -la ~/.gcp/credentials/terraform-dataops-key.json

# If missing, regenerate key
gcloud iam service-accounts keys create ~/.gcp/credentials/terraform-dataops-key.json \
  --iam-account=terraform-dataops@manish-sandpit.iam.gserviceaccount.com
```

#### **Issue: Terraform Provider Errors**
```bash
# Clear terraform cache
rm -rf .terraform/

# Re-initialize with service account
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.gcp/credentials/terraform-dataops-key.json"
terraform init
```

## 🔄 **Key Rotation (Security Best Practice)**

### **Quarterly Key Rotation (Recommended)**

```bash
# 1. List existing keys
gcloud iam service-accounts keys list \
  --iam-account=terraform-dataops@manish-sandpit.iam.gserviceaccount.com

# 2. Create new key
gcloud iam service-accounts keys create ~/.gcp/credentials/terraform-dataops-key-new.json \
  --iam-account=terraform-dataops@manish-sandpit.iam.gserviceaccount.com

# 3. Test new key
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.gcp/credentials/terraform-dataops-key-new.json"
terraform plan

# 4. If working, replace old key
mv ~/.gcp/credentials/terraform-dataops-key.json ~/.gcp/credentials/terraform-dataops-key-old.json
mv ~/.gcp/credentials/terraform-dataops-key-new.json ~/.gcp/credentials/terraform-dataops-key.json

# 5. Delete old key from GCP (get KEY_ID from step 1)
gcloud iam service-accounts keys delete KEY_ID \
  --iam-account=terraform-dataops@manish-sandpit.iam.gserviceaccount.com

# 6. Clean up local old key
rm ~/.gcp/credentials/terraform-dataops-key-old.json
```

## 🏢 **Team Setup**

### **For New Team Members**

1. **Grant IAM permissions** to create service account keys:
```bash
gcloud projects add-iam-policy-binding manish-sandpit \
  --member="user:new-member@intelia.com.au" \
  --role="roles/iam.serviceAccountKeyAdmin"
```

2. **Share this guide** with new team members

3. **Each team member should**:
   - Follow Steps 1-7 above
   - Generate their own service account key
   - Never share key files

### **For CI/CD Pipelines**

```bash
# Create key for CI/CD (store in secure secrets management)
gcloud iam service-accounts keys create ci-cd-key.json \
  --iam-account=terraform-dataops@manish-sandpit.iam.gserviceaccount.com

# In CI/CD pipeline, set environment variable:
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/ci-cd-key.json"
```

## 🛡️ **Security Best Practices**

### **✅ Do's**
- ✅ Use dedicated service account for terraform
- ✅ Store keys in secure location (`~/.gcp/credentials/`)
- ✅ Set restrictive file permissions (600)
- ✅ Rotate keys every 90 days
- ✅ Use environment variables, not hardcoded paths
- ✅ Each team member has their own key
- ✅ Delete unused keys from GCP

### **❌ Don'ts**
- ❌ Never commit service account keys to git
- ❌ Never share key files between team members
- ❌ Never use keys with broader permissions than needed
- ❌ Never store keys in project directories
- ❌ Never use personal accounts for automation
- ❌ Never leave old keys active after rotation

## 📞 **Support**

### **If you encounter issues:**

1. **Check this guide** for troubleshooting steps
2. **Verify permissions** using verification commands
3. **Regenerate keys** if authentication fails
4. **Contact team lead** for IAM permission issues

### **Emergency Key Recovery**

If you lose access to service account keys:

```bash
# Re-authenticate with personal account
gcloud auth login

# Generate new service account key
gcloud iam service-accounts keys create ~/.gcp/credentials/terraform-dataops-key.json \
  --iam-account=terraform-dataops@manish-sandpit.iam.gserviceaccount.com

# Test access
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.gcp/credentials/terraform-dataops-key.json"
terraform plan
```

---

## 📋 **Quick Reference**

### **Essential Commands**
```bash
# Set credentials
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.gcp/credentials/terraform-dataops-key.json"

# Use helper script
./terraform-sa.sh plan

# Test service account
gcloud projects list --filter="projectId:manish-sandpit"

# Check permissions
gcloud projects get-iam-policy manish-sandpit --filter="bindings.members:terraform-dataops@manish-sandpit.iam.gserviceaccount.com"
```

### **File Locations**
- **Service Account Key**: `~/.gcp/credentials/terraform-dataops-key.json`
- **Helper Script**: `infrastructure/terraform-sa.sh`
- **Terraform Config**: `infrastructure/main.tf`
- **Variable Example**: `infrastructure/terraform.tfvars.example`

This guide ensures secure, consistent service account setup across your team and environments.