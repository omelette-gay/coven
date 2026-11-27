# The realm's user profile: which attributes users have, who can see and edit them, and how they're checked. This
# resource replaces the whole profile, so it has to repeat Keycloak's default attributes (username, email, first and
# last name) as well as adding ours.
locals {
  user_profile_view_edit = { view = ["admin", "user"], edit = ["admin", "user"] }
}

resource "keycloak_realm_user_profile" "omelette_gay" {
  realm_id = keycloak_realm.omelette_gay.id

  attribute {
    name         = "username"
    display_name = "$${username}"

    permissions {
      view = local.user_profile_view_edit.view
      edit = local.user_profile_view_edit.edit
    }

    validator {
      name   = "length"
      config = { min = "3", max = "255" }
    }
    validator {
      name = "username-prohibited-characters"
    }
    validator {
      name = "up-username-not-idn-homograph"
    }
  }

  attribute {
    name               = "email"
    display_name       = "$${email}"
    required_for_roles = ["user"]

    permissions {
      view = local.user_profile_view_edit.view
      edit = local.user_profile_view_edit.edit
    }

    validator {
      name = "email"
    }
    validator {
      name   = "length"
      config = { max = "255" }
    }
  }

  attribute {
    name               = "firstName"
    display_name       = "$${firstName}"
    required_for_roles = ["user"]

    permissions {
      view = local.user_profile_view_edit.view
      edit = local.user_profile_view_edit.edit
    }

    validator {
      name   = "length"
      config = { max = "255" }
    }
    validator {
      name = "person-name-prohibited-characters"
    }
  }

  attribute {
    name               = "lastName"
    display_name       = "$${lastName}"
    required_for_roles = ["user"]

    permissions {
      view = local.user_profile_view_edit.view
      edit = local.user_profile_view_edit.edit
    }

    validator {
      name   = "length"
      config = { max = "255" }
    }
    validator {
      name = "person-name-prohibited-characters"
    }
  }

  # Each person's Vikunja API token for MCP, which they paste in themselves on their account page. It's only put in
  # access tokens for the Vikunja MCP client (see tfmodules/vikunja and ADR 008). It's stored unencrypted in Keycloak's
  # database and its backups, and realm admins can read it
  attribute {
    # Must match mcp_token_attribute in tfmodules/vikunja
    name         = "vikunja_mcp_token"
    display_name = "Vikunja MCP token"

    permissions {
      view = local.user_profile_view_edit.view
      edit = local.user_profile_view_edit.edit
    }

    validator {
      name   = "length"
      config = { max = "255" }
    }

    annotations = {
      inputHelperTextAfter = "An API token from Vikunja's settings, with the mcp:access scope and without delete permissions. Lets Claude use Vikunja as you."
    }
  }

  group {
    name                = "user-metadata"
    display_header      = "User metadata"
    display_description = "Attributes, which refer to user metadata"
  }
}
