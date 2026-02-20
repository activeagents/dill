# Google SSO Setup

Dill uses Google OAuth2 for authentication, restricting access to authorized domains.

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `GOOGLE_CLIENT_ID` | Yes | Google OAuth2 client ID |
| `GOOGLE_CLIENT_SECRET` | Yes | Google OAuth2 client secret |
| `ALLOWED_DOMAINS` | Yes | Comma-separated list of allowed email domains (e.g., `dill.vc,svsg.co`) |
| `AUTO_PROVISION_USERS` | No | Set to `true` to auto-create users from allowed domains on first login. Default: `false` |

## Google Cloud Console Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Navigate to **APIs & Services > Credentials**
4. Click **Create Credentials > OAuth client ID**
5. Select **Web application**
6. Add authorized redirect URIs:
   - Development: `http://localhost:3000/auth/google_oauth2/callback`
   - Production: `https://your-domain.com/auth/google_oauth2/callback`
7. Copy the Client ID and Client Secret

## Configuration Examples

### Development (.env.local)

```bash
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-client-secret
ALLOWED_DOMAINS=dill.vc,svsg.co
AUTO_PROVISION_USERS=false
```

### Production (Cloud Run)

Set environment variables in `terraform/main.tf` or via the GCP Console:

```hcl
env {
  name  = "GOOGLE_CLIENT_ID"
  value = "your-client-id.apps.googleusercontent.com"
}

env {
  name  = "GOOGLE_CLIENT_SECRET"
  value_source {
    secret_key_ref {
      secret  = "google-oauth-client-secret"
      version = "latest"
    }
  }
}

env {
  name  = "ALLOWED_DOMAINS"
  value = "dill.vc,svsg.co"
}

env {
  name  = "AUTO_PROVISION_USERS"
  value = "false"
}
```

## First-Time Setup

1. Set the required environment variables
2. Visit `/first_run` (redirected automatically if no users exist)
3. Click "Sign in with Google"
4. The first user to sign in becomes the admin

## User Provisioning Options

### Manual (default)
- Admin creates users via the admin panel
- Users can then sign in with Google if their email matches

### Auto-Provisioning
- Set `AUTO_PROVISION_USERS=true`
- Any user with an email from `ALLOWED_DOMAINS` can sign in
- New users are created automatically as members

## Security Notes

- Only emails from `ALLOWED_DOMAINS` can authenticate
- If `ALLOWED_DOMAINS` is empty, domain restriction is disabled (not recommended for production)
- User sessions are managed via secure, signed cookies
- OAuth tokens are not stored; only user profile info (email, name, avatar) is saved
