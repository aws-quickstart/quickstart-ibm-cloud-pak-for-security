# Breaking Changes
Backup/restore policy has been modified for the new couchDB operator.

# What’s new in Chart Version 1.0.8
New mount point has been added, instead of `/opt/backup/` we are now mounting to `/opt/data/`

# Fixes
No fixes

# Prerequisites
* Kubernetes 1.16

# Version History
| Chart | Date | Kubernetes Required | Image(s) Supported | Breaking Changes | Details |
| ----- | ---- | ------------ | ------------------ | ---------------- | ------------ |
| 1.0.0 | 10/08/20 | yes | cp4s-toolbox | yes | Backup&restore policy has been modified for new couchDB |
