# Run from the repo root: tflint --recursive --config "$PWD/.tflint.hcl"
# (--config is needed, or --recursive looks for a config file in each folder)
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}
