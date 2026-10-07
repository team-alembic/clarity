defmodule Demo.Accounts.OnboardOrganization do
  @moduledoc """
  Onboards a brand-new organization end-to-end.

  Creates the organization, registers its owner user, grants an owner
  membership, issues an API token, and writes an audit event. Wired with
  plain `step` blocks (rather than `Ash.Reactor` create/update steps) so
  the demo workflow stays free of the multi-tenancy / authorization
  plumbing the real resources require — the goal here is to give Clarity's
  *Reactor Flow* tab something representative to visualise.

  Inputs:
    * `:org_name` — display name for the new organization.
    * `:owner_email` — email of the seed owner user.
  """

  use Reactor

  input :org_name do
    description "Display name for the organization being created."
  end

  input :owner_email do
    description "Email address of the seed owner user."
  end

  step :create_organization do
    description "Persist a brand-new Organization record on the free plan."
    argument(:name, input(:org_name))

    run(fn %{name: name}, _context ->
      {:ok, %{id: System.unique_integer([:positive]), name: name}}
    end)
  end

  step :create_owner_user do
    description "Register the seed owner user inside the new organization."
    argument(:email, input(:owner_email))
    argument(:org, result(:create_organization))

    run(fn %{email: email, org: org}, _context ->
      {:ok, %{id: System.unique_integer([:positive]), email: email, org_id: org.id}}
    end)
  end

  step :grant_membership do
    description "Promote the user to owner with full admin scopes."
    argument(:user, result(:create_owner_user))
    argument(:org, result(:create_organization))

    run(fn %{user: user, org: org}, _context ->
      {:ok, %{user_id: user.id, org_id: org.id, role: :owner}}
    end)
  end

  step :issue_api_token do
    description "Mint an API token the owner can use immediately."
    argument(:user, result(:create_owner_user))

    run(fn %{user: user}, _context ->
      {:ok, %{user_id: user.id, token: "tok_" <> Integer.to_string(user.id)}}
    end)
  end

  step :record_audit_event do
    description "Log the onboarding so it's discoverable in audit history."
    argument(:user, result(:create_owner_user))
    argument(:org, result(:create_organization))
    argument(:token, result(:issue_api_token))
    argument(:membership, result(:grant_membership))

    run(fn %{user: user, org: org, token: token, membership: membership}, _context ->
      {:ok,
       %{
         type: :organization_onboarded,
         user_id: user.id,
         org_id: org.id,
         token_id: token.token,
         role: membership.role
       }}
    end)
  end

  return(:record_audit_event)
end
