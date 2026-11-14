# GitHub domain verification

Creates the Hetzner DNS records GitHub uses to verify that an organisation owns a domain.

- `verification_code` is from the organisation's **Settings → Verified and approved domains**, and creates the
  `_gh-<organisation>-o` TXT record.
- `pages_verification_code` is optional, and is from the organisation's **Settings → Pages → Verified domains**. It
  creates the `_github-pages-challenge-<organisation>` TXT record, which stops anyone outside the organisation from
  using the domain or its subdomains for their own GitHub Pages site.

Verification codes aren't secret, as they're published in DNS anyway.

After the records have been applied, click **Verify** next to the domain in the same GitHub settings page.
