# Terraform AWS SAA

In this repo, you'll find a quick and easy app to get started using [Terraform Cloud](https://app.terraform.io/) with AWS.

## Configuration

1. Copiez le fichier template:
   ```bash
   cp terraform.tf.example terraform.tf
   ```

2. Modifiez `terraform.tf` avec vos valeurs:
   - organization
   - workspace name
   - région AWS si différente

3. Dans Terraform Cloud:
   - Créez un workspace
   - Ajoutez les variables d'environnement:
     - AWS_ACCESS_KEY_ID (Sensitive: Yes)
     - AWS_SECRET_ACCESS_KEY (Sensitive: Yes)

## Infrastructure

Cette configuration crée:
- Une instance EC2 avec Apache
- Un volume EBS pour les données
- Les groupes de sécurité nécessaires
- Les rôles IAM requis

## Version Control Workflow

Le workflow utilise Terraform Cloud avec GitHub. Les commits sur la branche principale déclenchent automatiquement les plans Terraform.

## Notes de sécurité

- Ne committez jamais `terraform.tf` avec des informations sensibles
- Utilisez toujours des variables d'environnement pour les credentials
- Gardez les clés SSH et autres secrets hors du contrôle de version