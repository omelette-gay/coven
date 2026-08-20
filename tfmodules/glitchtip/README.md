# GlitchTip

Deploys GlitchTip (error monitoring software).

## Requirements

Before applying Terraform, create the application secret manually in Vault at `secret/glitchtip/app`. It must contain:

```text
SECRET_KEY=<a long random value>
```
