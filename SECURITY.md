# Security Guidelines

## 🚨 CRITICAL: Never Commit These Files

### Terraform Files
- `*.tfstate` - Contains credentials, API keys, resource details
- `*.tfstate.backup` - Backup state with same sensitive data
- `*.tfvars` - Variable files often contain passwords/keys
- `.terraform/` - Cache directory with potential credentials

### Credentials & Keys
- Private keys (`*.key`, `*.pem`, `id_rsa*`)
- API keys and tokens
- Database passwords
- Service account JSON files
- Certificate files

### Environment Files
- `.env` - Environment variables with secrets
- `*.env.*` - Environment-specific configurations
- Config files with hardcoded credentials

## ✅ Safe Practices

### 1. Use Remote State
```terraform
terraform {
  backend "gcs" {
    bucket = "your-terraform-state-bucket"
    prefix = "terraform/state"
  }
}
```

### 2. Environment Variables
```bash
export TF_VAR_database_password="secure_password"
export GOOGLE_APPLICATION_CREDENTIALS="path/to/service-account.json"
```

### 3. Secret Management
- Use Google Secret Manager
- Use HashiCorp Vault
- Use environment variables
- Never hardcode secrets

### 4. Pre-commit Hooks
Install and use pre-commit hooks:
```bash
pip install pre-commit
pre-commit install
```

## 🛡️ Repository Protection

This repository has:
- ✅ Comprehensive `.gitignore`
- ✅ `.gitattributes` for file handling
- ✅ Pre-commit hooks for secret detection
- ✅ Automated checks for sensitive files

## 📋 Security Checklist

Before any commit:
- [ ] Check for hardcoded credentials
- [ ] Verify `.tfstate` files not staged
- [ ] Ensure `.env` files not included
- [ ] Run `git status` to review all changes
- [ ] Use `git diff --cached` to review staged changes

## 🚨 If Sensitive Data Is Committed

1. **STOP** - Don't push if not already pushed
2. **Remove** from git: `git rm --cached <file>`
3. **Clean history**: Use `git filter-branch` or `BFG Repo-Cleaner`
4. **Force push**: `git push --force` (if already pushed)
5. **Rotate credentials** that may have been exposed
6. **Review** access logs for potential unauthorized access

## 📞 Security Incident Response

If sensitive data was committed to a public repository:
1. **Immediately** make repository private
2. **Rotate** all potentially exposed credentials
3. **Clean** git history completely
4. **Audit** access logs
5. **Update** security practices