<!--
SPDX-FileCopyrightText: 2024 Alembic Pty Ltd

SPDX-License-Identifier: MIT
-->

# Authentication Metadata

When users authenticate through `ash_authentication`, metadata is attached to the user record to track which authentication strategies were used and when. This metadata is useful for:

- Enforcing multi-factor authentication requirements
- Auditing authentication events
- Implementing time-based re-verification
- Building security dashboards

## Metadata Structure

After successful authentication, the following metadata keys are set on the user record:

### `authentication_strategies`

A list of atoms representing which authentication strategies were used in the current authentication flow.

```elixir
user.__metadata__.authentication_strategies
#=> [:password]

# Or for TOTP
#=> [:totp]
```

**Common values:**
- `[:password]` - User authenticated with password
- `[:totp]` - User authenticated with TOTP code
- `[:magic_link]` - User authenticated via magic link
- `[:oauth2]` - User authenticated via OAuth2 provider

### `totp_verified_at`

A `DateTime` indicating when TOTP verification occurred. Only set after successful TOTP authentication.

```elixir
user.__metadata__.totp_verified_at
#=> ~U[2024-01-15 10:30:00Z]
```

### `token`

The authentication token (JWT) for the session. Always set when tokens are enabled.

```elixir
user.__metadata__.token
#=> "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

## Accessing Metadata

### In Controllers

```elixir
defmodule MyAppWeb.DashboardController do
  use MyAppWeb, :controller

  def index(conn, _params) do
    user = conn.assigns.current_user

    # Check authentication strategies used
    strategies = user.__metadata__[:authentication_strategies] || []

    # Check if TOTP was used
    totp_used = :totp in strategies

    # Check when TOTP was verified
    totp_verified_at = user.__metadata__[:totp_verified_at]

    render(conn, :index,
      totp_used: totp_used,
      totp_verified_at: totp_verified_at
    )
  end
end
```

### In LiveViews

```elixir
defmodule MyAppWeb.SecurityLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    metadata = user.__metadata__

    {:ok,
      assign(socket,
        auth_strategies: metadata[:authentication_strategies] || [],
        totp_verified_at: metadata[:totp_verified_at]
      )}
  end
end
```

### In Templates

```heex
<div class="security-info">
  <h3>Current Session</h3>

  <p>Authenticated with:
    <%= Enum.map_join(@auth_strategies, ", ", &to_string/1) %>
  </p>

  <%= if @totp_verified_at do %>
    <p class="text-green-600">
      TOTP verified at: <%= Calendar.strftime(@totp_verified_at, "%Y-%m-%d %H:%M UTC") %>
    </p>
  <% end %>
</div>
```

## Common Use Cases

### Requiring Recent TOTP Verification

For sensitive operations, require that TOTP was verified recently:

```elixir
defmodule MyApp.Security do
  @max_totp_age_minutes 15

  def recent_totp_verification?(user) do
    case user.__metadata__[:totp_verified_at] do
      nil ->
        false

      verified_at ->
        age_minutes = DateTime.diff(DateTime.utc_now(), verified_at, :minute)
        age_minutes < @max_totp_age_minutes
    end
  end
end
```

### Building an Audit Log

Track authentication events using the metadata:

```elixir
defmodule MyApp.AuthAudit do
  def log_authentication(user, conn) do
    MyApp.AuditLog.create!(%{
      user_id: user.id,
      strategies: user.__metadata__[:authentication_strategies] || [],
      totp_verified: user.__metadata__[:totp_verified_at] != nil,
      ip_address: get_ip(conn),
      user_agent: get_user_agent(conn),
      timestamp: DateTime.utc_now()
    })
  end

  defp get_ip(conn) do
    conn.remote_ip |> :inet.ntoa() |> to_string()
  end

  defp get_user_agent(conn) do
    Plug.Conn.get_req_header(conn, "user-agent") |> List.first()
  end
end
```

### Conditional UI Based on Auth Method

Show different UI elements based on how the user authenticated:

```elixir
defmodule MyAppWeb.Components.SecurityBadge do
  use Phoenix.Component

  def security_badge(assigns) do
    ~H"""
    <div class="flex gap-2">
      <%= for strategy <- @strategies do %>
        <span class={badge_class(strategy)}>
          <%= badge_text(strategy) %>
        </span>
      <% end %>
    </div>
    """
  end

  defp badge_class(:totp), do: "badge badge-green"
  defp badge_class(:password), do: "badge badge-blue"
  defp badge_class(_), do: "badge badge-gray"

  defp badge_text(:totp), do: "2FA Verified"
  defp badge_text(:password), do: "Password"
  defp badge_text(:magic_link), do: "Magic Link"
  defp badge_text(:oauth2), do: "OAuth"
  defp badge_text(other), do: to_string(other)
end
```

## Metadata Lifecycle

### When Metadata is Set

Metadata is set during the authentication preparation phase:

1. **Password sign-in**: Sets `authentication_strategies: [:password]`
2. **TOTP sign-in**: Sets `authentication_strategies: [:totp]` and `totp_verified_at`
3. **Token generation**: Sets `token` with the JWT

### When Metadata is Lost

Metadata exists only on the in-memory user struct. It is **not** persisted to the database. This means:

- Metadata is lost when you reload the user from the database
- Each authentication creates fresh metadata
- Metadata should be accessed immediately after authentication

If you need persistent tracking, store relevant data in your database or session.

### Preserving Metadata Through Requests

The authentication token (JWT) carries the session identity. When the token is validated on subsequent requests, you get a fresh user struct without the original metadata.

For persistent metadata needs, consider:

1. **Session storage**: Store in Phoenix session
2. **Database**: Create an `auth_sessions` table
3. **Token claims**: Embed in JWT claims (for read-only data)

Example using session storage:

```elixir
# In your auth controller callback
def callback(conn, _params) do
  user = conn.assigns.subject

  conn
  |> put_session(:auth_strategies, user.__metadata__[:authentication_strategies])
  |> put_session(:totp_verified_at, user.__metadata__[:totp_verified_at])
  |> redirect(to: "/")
end

# In a plug to restore metadata
def restore_auth_metadata(conn, _opts) do
  if user = conn.assigns[:current_user] do
    user =
      user
      |> Ash.Resource.put_metadata(:authentication_strategies, get_session(conn, :auth_strategies))
      |> Ash.Resource.put_metadata(:totp_verified_at, get_session(conn, :totp_verified_at))

    assign(conn, :current_user, user)
  else
    conn
  end
end
```

## Strategy-Specific Metadata

### Password Strategy

Sets only `authentication_strategies`:

```elixir
%{
  authentication_strategies: [:password],
  token: "..."
}
```

**Note**: Sign-in tokens (intermediate tokens for features like sign-in links) do **not** set `authentication_strategies` since authentication is not yet complete.

### TOTP Strategy

Sets both strategy and verification timestamp:

```elixir
%{
  authentication_strategies: [:totp],
  totp_verified_at: ~U[2024-01-15 10:30:00Z],
  token: "..."
}
```

### Multi-Factor Authentication Flow

When using password + TOTP two-factor authentication, the metadata accumulates strategies:

```elixir
# After password + TOTP verification
%{
  authentication_strategies: [:password, :totp],
  totp_verified_at: ~U[2024-01-15 10:30:00Z],
  token: "..."
}
```

## Related Documentation

- [TOTP Authentication](totp.md) - Primary TOTP authentication
- [TOTP as Second Factor](totp-2fa.md) - Using TOTP for 2FA
- [LiveView Integration](liveview.md) - Accessing user in LiveViews
