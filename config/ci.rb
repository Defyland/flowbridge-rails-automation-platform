# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Contract: OpenAPI YAML parses", %(ruby -e 'require "yaml"; YAML.load_file("openapi.yaml")')
  step "Contract: serverless ingress normalizer", "ruby -I services/serverless/webhook_ingress/lib services/serverless/webhook_ingress/test/flowbridge_serverless_ingress_test.rb"
  step "Infra: OpenTofu/Terraform serverless ingress", "ASDF_TERRAFORM_VERSION=1.9.8 bin/infra-check"
  step "Tests: Rails", "bin/rails test:all"
  step "Tests: System", "bin/rails test:system"
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
