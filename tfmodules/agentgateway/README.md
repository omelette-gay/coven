# agentgateway

Puts [agentgateway](https://agentgateway.dev/) in front of an MCP server that takes a per-user bearer token but
doesn't do OAuth itself, so that clients which need OAuth (such as claude.ai's custom connectors) can use it as each
person rather than as one shared identity. It uses the standalone chart, with its config in a read-only ConfigMap.

For each request, the gateway:

1. Checks the caller's access token against the OIDC issuer: its signature, expiry, issuer, and that its audience is
   the MCP endpoint's URL. Without a valid token it returns 401 with a pointer to the protected resource metadata,
   which tells the client where to log in.
2. Refuses the request if the token has no `credential_claim`.
3. Replaces the `Authorization` header with `Bearer <credential_claim>` and forwards the request to the upstream, so
   the upstream never sees the access token, and checks its own permissions as that person.

Nothing in it is specific to an identity provider: the issuer has to put each person's credential for the upstream in
their access tokens, and give the tokens the MCP endpoint's URL (`https://<host><path>`) as their audience. For
Keycloak, that's a user attribute mapper and an audience mapper on the client the MCP client logs in with (see the
[vikunja](../vikunja/) module).

## Routing

The ingress only claims `path` and `/.well-known/oauth-protected-resource<path>` on `host`, with exact matches.
Traefik prefers the longer rule, so the upstream's own ingress for the whole host keeps everything else, and the MCP
endpoint keeps the address the upstream documents. It reuses the upstream's TLS Secret rather than requesting a
certificate of its own.

## Security

The credential is in the access token, so anyone holding a valid access token can read it. Access tokens only go to
the MCP client and this gateway, and are short-lived, but the credential inside them isn't. Refresh tokens are tied to
the client's secret, and can be revoked in the identity provider. See
[ADR 008](../../docs/adr/008-put-an-oauth-gateway-in-front-of-vikunjas-mcp-server.md).
