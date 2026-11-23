# Single sign-on with Keycloak

Keycloak (https://auth.coven.omelette.gay) is our identity provider. This guide explains how apps use it, what
controls who can do what in each app today, and what to check when putting a new app behind SSO. Read it before adding
or changing a Keycloak client, or before giving someone new an account.

## How it works

### Realms, users and groups

- The `master` realm is only for administering Keycloak itself.
- The `omelette.gay` realm holds everyone who logs in to our apps.
- The `admins` group in `omelette.gay` is for Chris and Meg. It's given the admin role in Vault and Grafana (and Planka, until it's deleted),
  and Vault admin can read every secret and issue cluster-admin Kubernetes credentials. Treat membership of `admins` as
  full control of everything.
- Anyone else (for example friends using a tool we host) should be in a group that describes them, such as `friends`,
  and never in `admins`.

### Clients, roles and tokens

Each app has its own **client** in the `omelette.gay` realm. A client can have **client roles**, which are granted to
users or groups. Each client has a protocol mapper that puts that client's roles into the token, usually in a claim
called `roles`.

The mapper only includes roles from its own client, so one app's roles never appear in another app's token. This
matters because role names are reused: Home Assistant has an `admin` role, and so do other apps. Vault also checks the
token's audience, so a token issued to another client can't be used to log in to Vault.

### Keycloak authenticates, the app authorises

**Any enabled user in the `omelette.gay` realm can log in to any client.** Keycloak has no setting that limits a client
to particular users or groups, so it doesn't stop someone logging in to an app they've been given no roles in. It only
confirms who they are and passes their roles to the app. Whether they can then do anything is decided entirely by the
app.

An app can treat a user with none of its roles in one of three ways:

1. **It refuses the login.** The app requires a role and turns away anyone without it.
2. **It lets them in with no access.** The app creates an account, but it can't see or change anything until someone
   grants access inside the app.
3. **It lets them in with useful access.** The app creates an account that can already use it, or can create things of
   its own.

The first two are safe to give someone a Keycloak account for. The third means everyone in the realm can use that app.
That can be acceptable, but it should be a deliberate choice.

## Current apps

| App | Client defined in | Gated by | A user with no roles gets |
|---|---|---|---|
| Vault | `tfmodules/stack-platform/vault.tf` | Vault's OIDC role only accepts tokens with its admin role (`bound_claims`) and audience (`bound_audiences`) | Login refused (1) |
| Grafana | `tfmodules/stack-platform/monitoring.tf` (via `tfmodules/keycloak-client`); gate in `tfmodules/kube-prometheus-stack/values/grafana.yaml.tftpl` | `role_attribute_path` only gives a role to admins, and `role_attribute_strict` refuses anyone else | Login refused (1) |
| Home Assistant | `coven/apps/home-assistant.tf`; gate in the `omelette-gay/home-assistant` chart | `auth_oidc` `roles.user` is `resident` and `roles.admin` is `admin`, so users need one of them | Login refused (1) |
| Wedding | `coven/apps/wedding.tf`; gate in `omelette-gay/wedding` | Django admin requires `is_staff`, which SSO-created users don't have. RSVPs use invite codes, not login | An account that can't see anything (2) |
| GlitchTip | `tfmodules/glitchtip` (via `tfmodules/keycloak-client`) | Everything is inside organizations. New users belong to none, and only superusers can create them (`ENABLE_ORGANIZATION_CREATION` defaults to false) | An account that can't see anything until invited to an organization (2) |
| Planka | Nowhere: its Ansible role was deleted, and it's left running unmanaged until it's removed (#592) | Only admin rights come from Keycloak | An account that can use Planka (3). Accepted because Planka is being decommissioned |
| Vikunja | `tfmodules/vikunja` (via `tfmodules/keycloak-client`) | Nothing: Vikunja's OpenID login can't require a role or group claim | Their own empty account, which can create projects but sees nobody else's unless they're shared with it (3). Accepted |

Things to know about these:

- **Home Assistant has no per-device permissions for non-admin users.** The `resident` role can control everything in
  the house, including locks and heating. Only give it to people who live there.
- **Any realm user can use Vikunja.** It has no setting to require a role or group claim (checked at v2.8.0), so
  everyone in `omelette.gay` gets an account. That account only sees projects it creates or that are shared with it,
  so it can't see Chris and Meg's tasks. Accounts are linked to Keycloak by issuer and `sub`, not email.
- **Role mappings are made by Terraform.** The platform stack maps Vault's `vault-admin` and Grafana's `grafana-admin`
  roles to `admins`, and the apps stack maps Home Assistant's `admin` role to `admins` (`role_groups` in
  `coven/apps/home-assistant.tf`). Planka's mapping was made by Ansible and is left as it is until Planka is removed. Nobody has
  its `resident` role, as nobody but Chris and Meg lives there. See [known gaps](#known-gaps).

### Realm settings that affect everyone

- **Default roles** (Realm settings → User registration → Default roles) are given to every user. They should only be
  `offline_access`, `uma_authorization` and the `account` client's roles. Never add `realm-management` roles or app
  roles here.
- **Self-registration** is off (`registration_allowed = false` in `tfmodules/stack-platform/keycloak.tf`).
- **Users can edit their own profile**, including their email address, through the account console. Apps shouldn't
  trust an email address to identify an existing account unless it's verified.

## Integrating a new app

### 1. Find out how the app handles roles

Before writing any code, read the app's SSO documentation and work out which of the [three
types](#keycloak-authenticates-the-app-authorises) it is. In particular:

- Can it require a role or group claim to log in at all?
- Does it create accounts automatically on first login? If so, what can a new account do by default? Can it create its
  own projects, organizations, boards or similar?
- How does it match an SSO login to an existing account? By the `sub` claim, username, or email?
- Does it have its own sign-up form or local accounts that need turning off?

If the app is type 3, decide whether that's acceptable for everyone in the realm before going ahead. If it isn't, see
[when a custom login flow is needed](#when-a-custom-login-flow-is-needed).

### 2. Create the client with the `keycloak-client` module

New SSO clients should use [tfmodules/keycloak-client](../tfmodules/keycloak-client/), from the app's own module,
as [tfmodules/glitchtip](../tfmodules/glitchtip/main.tf) does:

```hcl
module "keycloak_client" {
  source = "../keycloak-client"

  keycloak_url        = var.keycloak_url
  keycloak_realm      = var.keycloak_realm
  client_id           = "example"
  client_name         = "Example"
  valid_redirect_uris = ["https://${var.domain}/oidc/callback"]
  client_roles        = ["admin", "user"]
  role_groups         = { admin = ["admins"] }
  k8s_namespace       = kubernetes_namespace_v1.this.metadata[0].name
  k8s_secret_name     = "example-oidc"

  depends_on = [kubernetes_namespace_v1.this]
}
```

The module creates:

- a confidential client with the standard (authorization code) flow,
- the client roles in `client_roles`,
- a mapper that adds this client's roles to the `roles` claim in the ID token, access token and userinfo, and
- a Kubernetes Secret with the keys `client_id`, `client_secret`, `authorization_endpoint`, `token_endpoint`,
  `userinfo_endpoint` and `jwks_endpoint`. Every client has the same keys, so point the app at whichever it needs.

It only grants roles to the groups in `role_groups`, which must already exist (or, in the platform stack, which makes
the `admins` group, be passed in `group_ids`). It doesn't create groups or manage who's
in them, and it never removes a role from a group, so grants made in the Keycloak UI stay. Anything not in
`role_groups` has to be granted in the UI until the other apps move (see [known gaps](#known-gaps)). Record which group
has which role in the [current apps](#current-apps) table.

Keep `valid_redirect_uris` to the exact callback URLs the app uses, not wildcards.

Self-deploying apps use the same module, from their own file in `coven/apps/` (see
[deploying apps](./deploying-apps.md)).

### 3. Configure the app

- **Require a role to log in** where the app supports it, using the `roles` claim. Prefer this over letting users in
  with no access.
- **Set access options explicitly**, even where they match the app's defaults. A default can change in an upgrade
  merged by Renovate. For example, GlitchTip only stops users creating organizations because
  `ENABLE_ORGANIZATION_CREATION` defaults to false.
- **Turn off the app's own sign-up and local logins**, so SSO is the only way in.
- **Don't link logins to existing accounts by email** unless the app checks the `email_verified` claim. Users can
  change their own email in Keycloak. Match on `sub` where possible.
- **Block metrics endpoints** at Traefik if the app serves them on its public host, as Keycloak, GlitchTip, wedding and
  Home Assistant do.

### 4. Check what a user with no roles gets

In the Keycloak admin console, **Clients → (the client) → Client scopes → Evaluate** shows the token a given user would
receive for that client, without logging in as them. Use it to check the roles claim contains what you expect for an
admin and for a user with no roles.

Then add the app to the [current apps](#current-apps) table, including what a user with no roles gets.

### When a custom login flow is needed

Keycloak can refuse a login before it reaches the app, using a custom authentication flow (a "Condition - user role"
step followed by "Deny access") bound to particular clients. This gives the same effect as requiring assignment to an
app in other identity providers.

It's worth building if a new app:

- can't check roles or groups itself, or
- gives users useful access by default and can't be configured not to, or
- controls something where a mistake would be serious enough to want a second check, even though the app checks roles
  too. Home Assistant is the strongest candidate today.

Every app so far either checks roles itself or is accepted as open, so we haven't built one. If we do, it's a new
feature: build it in the testlab first, manage it with Terraform, and record the decision in an
[ADR](./adr/README.md).

## Known gaps

- **Group membership isn't in code.** The realm, the `admins` group and the role mappings are in Terraform, but other
  groups and who's in each group are managed in the Keycloak UI. Because the module never removes a grant, a role added to a group by hand isn't reverted. See #904.
- **GlitchTip's `ENABLE_ORGANIZATION_CREATION` isn't set explicitly.** Set it to `false` in `tfmodules/glitchtip`.
- **Wedding links logins to existing accounts by email** without checking `email_verified` (`omelette_wedding/auth.py`
  in the wedding repo). Keycloak doesn't allow two users to share an email, which limits this, but it should match on
  `sub` or check `email_verified`.
- **Planka lets any realm user in with full use of it.** Accepted until it's removed (#592).
