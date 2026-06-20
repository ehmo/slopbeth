# Branch protection

Protect `main` so benchmark and package gates cannot be skipped.

## required status check

Require this check before merging:

```text
test
```

The check is produced by `.github/workflows/ci.yml`, which runs on Ubicloud.

## recommended settings

Use these repository settings for `main`:

- require a pull request before merging
- require status checks to pass before merging
- require branches to be up to date before merging
- require the `test` status check
- block force pushes
- block branch deletion
- include administrators if the repo should never bypass release gates

## API shape

The equivalent GitHub API payload is:

```json
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["test"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_linear_history": false,
  "required_conversation_resolution": false
}
```

If the check name appears in GitHub as `package / test`, require that exact context instead of `test`.
