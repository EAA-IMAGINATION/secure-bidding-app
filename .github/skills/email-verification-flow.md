# Email verification flow

All verification (registration, change email, resend) uses one path: email link → confirm page → API complete.

## Endpoints

| Step | App | API |
| --- | --- | --- |
| Send email | `POST /register`, profile resend, email change | `POST /auth/register`, account update/resend |
| Open link | `GET /verify-email?token=…` | — |
| Preview | App → `POST /auth/verification-preview` | Returns `{ purpose, username, email }` |
| Complete | `POST /verify-email` | `POST /auth/verify` (password only when `purpose` is `registration`) |

Email link (all flows): `{APP}/verify-email?token={token}`

Legacy `/register/verify/:token` redirects to `/verify-email?token=…`.

## Purpose values

- `registration` — new account; confirm page shows username, email, and password fields.
- `email_verification` — existing account (resend or change email); confirm page shows username and email only.

## Session

- Registration complete returns a session token; app stores the new account.
- Email verification returns updated account fields; app merges into the current session when logged in.

## Tyto comparison

- Tyto only supports registration verification.
- Secure Bidding adds `email_verified_at`, resend/change-email, and auto-login after registration verify.
