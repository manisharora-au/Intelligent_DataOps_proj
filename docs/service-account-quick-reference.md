# Service Account Quick Reference

## 🚀 **One-Line Setup**

```bash
# Run the automated setup script
./scripts/setup-service-account.sh
```

## 🔐 **Essential Commands**

### **Daily Usage**
```bash
# Option 1: Helper script (recommended)
cd infrastructure && ./terraform-sa.sh plan

# Option 2: Environment variable
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.gcp/credentials/terraform-dataops-key.json"
terraform plan
```

### **Quick Setup**
```bash
# 1. Authenticate
gcloud auth login

# 2. Set project
gcloud config set project manish-sandpit

# 3. Run setup script
./scripts/setup-service-account.sh
```

### **Manual Key Generation**
```bash
# Create new key
gcloud iam service-accounts keys create ~/.gcp/credentials/terraform-dataops-key.json \
  --iam-account=terraform-dataops@manish-sandpit.iam.gserviceaccount.com

# Secure permissions
chmod 600 ~/.gcp/credentials/terraform-dataops-key.json
```

### **Verification**
```bash
# Test service account
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.gcp/credentials/terraform-dataops-key.json"
gcloud projects list --filter="projectId:manish-sandpit"

# Check permissions
gcloud projects get-iam-policy manish-sandpit \
  --filter="bindings.members:terraform-dataops@manish-sandpit.iam.gserviceaccount.com"
```

## 🔄 **Key Rotation (Every 90 Days)**

```bash
# 1. Create new key
gcloud iam service-accounts keys create ~/.gcp/credentials/terraform-dataops-key-new.json \
  --iam-account=terraform-dataops@manish-sandpit.iam.gserviceaccount.com

# 2. Test new key
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.gcp/credentials/terraform-dataops-key-new.json"
terraform plan

# 3. Replace old key
mv ~/.gcp/credentials/terraform-dataops-key.json ~/.gcp/credentials/terraform-dataops-key-old.json
mv ~/.gcp/credentials/terraform-dataops-key-new.json ~/.gcp/credentials/terraform-dataops-key.json

# 4. Delete old key from GCP (get KEY_ID from: gcloud iam service-accounts keys list --iam-account=terraform-dataops@manish-sandpit.iam.gserviceaccount.com)
gcloud iam service-accounts keys delete KEY_ID --iam-account=terraform-dataops@manish-sandpit.iam.gserviceaccount.com

# 5. Clean up
rm ~/.gcp/credentials/terraform-dataops-key-old.json
```

## 🛠️ **Troubleshooting**

### **Permission Denied**
```bash
# Re-authenticate
gcloud auth login

# Verify file exists
ls -la ~/.gcp/credentials/terraform-dataops-key.json

# Check file permissions (should be -rw-------)
chmod 600 ~/.gcp/credentials/terraform-dataops-key.json
```

### **Service Account Not Found**
```bash
# Run setup script to create
./scripts/setup-service-account.sh

# Or create manually
gcloud iam service-accounts create terraform-dataops \
  --display-name="Terraform DataOps Service Account" \
  --project=manish-sandpit
```

### **Terraform Provider Errors**
```bash
# Clear cache and reinitialize
rm -rf .terraform/
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.gcp/credentials/terraform-dataops-key.json"
terraform init
```

## 📁 **File Locations**

| File | Location | Purpose |
|------|----------|---------|
| Service Account Key | `~/.gcp/credentials/terraform-dataops-key.json` | Authentication credentials |
| Helper Script | `infrastructure/terraform-sa.sh` | Easy terraform execution |
| Setup Script | `scripts/setup-service-account.sh` | Automated setup |
| Setup Guide | `docs/service-account-setup-guide.md` | Detailed instructions |

## 🔐 **Security Checklist**

- [ ] Service account key stored in `~/.gcp/credentials/`
- [ ] Key file permissions set to `600` (owner read/write only)
- [ ] Using dedicated service account (not personal account)
- [ ] Keys rotated every 90 days
- [ ] Old keys deleted from GCP after rotation
- [ ] Keys never committed to git
- [ ] Each team member has their own key

## 📞 **Emergency Recovery**

If you lose access to service account:

```bash
# 1. Authenticate with personal account
gcloud auth login

# 2. Regenerate service account key
gcloud iam service-accounts keys create ~/.gcp/credentials/terraform-dataops-key.json \
  --iam-account=terraform-dataops@manish-sandpit.iam.gserviceaccount.com

# 3. Test access
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.gcp/credentials/terraform-dataops-key.json"
terraform plan
```