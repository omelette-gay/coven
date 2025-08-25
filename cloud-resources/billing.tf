variable "billing_account_name" {
  description = "The billing account Name"
  type        = string
  default     = "My Billing Account"
}

variable "budget_value" {
  description = "The monthly budget value threshold"
  type        = number
  default     = 10
}


resource "google_monitoring_notification_channel" "budget_notification_channel_1" {
  display_name = "Notification Channel for Budget Alerts"
  type         = "email"

  labels = {
    email_address = "megchallinor83+gcpbilling@gmail.com"
  }
}

resource "google_monitoring_notification_channel" "budget_notification_channel_2" {
  display_name = "Notification Channel for Budget Alerts"
  type         = "email"

  labels = {
    email_address = "cnorthwood@gmail.com"
  }
}

data "google_billing_account" "account" {
  display_name = var.billing_account_name
  open         = true
}

resource "google_billing_budget" "warningbudget" {
  billing_account = data.google_billing_account.account.id
  display_name = "Billing Budget"
  amount {
    specified_amount {
      currency_code = "GBP"
      units = var.budget_value
    }
  }
  threshold_rules {
      threshold_percent =  0.8
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  all_updates_rule {
    monitoring_notification_channels = [
      google_monitoring_notification_channel.budget_notification_channel_1.id,
      google_monitoring_notification_channel.budget_notification_channel_2.id,
    ]
    disable_default_iam_recipients = false
  }
}
