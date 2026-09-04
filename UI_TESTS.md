# Manual UI test script

Run `./scripts/build.sh` once, then `./scripts/bootstrap.sh`. Open
<http://localhost:3000/branch-demo/team-deletion-demo>.

## 1. Verify the configuration UI

1. Sign in as `demo` / `DemoDelete123!`.
2. Open **Settings -> Branches -> release/** and edit the rule.
3. Under **Branch Deletion**, verify these three mutually exclusive choices:
   **Disable Branch Deletion**, **Enable Branch Deletion**, and
   **Allowlist Restricted Branch Deletion**.
4. Select the allowlist choice and verify the user and team selectors and the
   deploy-key checkbox appear.
5. Verify `release-managers` is selected under **Allowlisted teams for deleting**.
6. Verify **Allowlist deploy keys with push access to delete** is unchecked by
   default.

Expected appearance:

![Branch deletion team allowlist](docs/protected-branch-deletion.png)

## 2. Non-allowlisted writer is denied

1. Sign out and sign in as `developer` / `Developer123!`.
2. Open **Code -> Branches** and try to delete `release/team-1`.
3. Confirm Gitea refuses the deletion and the branch remains.

## 3. Allowlisted team member succeeds

1. Sign out and sign in as `releasebot` / `ReleaseBot123!`.
2. Open **Code -> Branches** and delete `release/team-1`.
3. Confirm the deletion succeeds.

## 4. An unprotected branch is unchanged

1. Sign in as `developer` again.
2. Delete `feature/control`.
3. Confirm the deletion succeeds normally.

Run `./scripts/bootstrap.sh` at any point to recreate deleted demo branches.
Run `./scripts/smoke-api.sh` to exercise the same allow/deny paths without the UI.
Run `./scripts/test-gitea.sh` to exercise the Gitea API and SSH deploy-key
integration tests against the configured source checkout.
