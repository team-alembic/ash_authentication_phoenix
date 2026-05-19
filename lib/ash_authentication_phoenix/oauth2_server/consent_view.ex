# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Oauth2Server.ConsentView do
  @moduledoc """
  Default HTML consent screen.

  An app can ship a custom consent screen by configuring its own module
  exporting `render(:consent, assigns)` and passing it to the router as
  `consent_view: MyApp.MyConsentView`.

  ## Assigns

    * `:client_name` — registered client display name
    * `:client_id` — UUID (for display)
    * `:redirect_uri` — where approval will redirect (for display)
    * `:scope` — the space-separated scope string requested (for display)
    * `:resource` — the resource URL the token will bind to (for display)
    * `:action_path` — POST destination for the consent form
    * `:csrf_token` — CSRF token to embed
    * `:consent_request` — sealed token capturing the validated request;
      the POST handler reconstructs all protocol fields from this rather
      than trusting form-submitted values.
  """

  require EEx

  EEx.function_from_string(
    :def,
    :render_consent,
    """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8">
        <title>Authorize <%= h(@client_name) %></title>
        <style>
          body { font-family: system-ui, -apple-system, sans-serif; max-width: 480px; margin: 4rem auto; padding: 0 1rem; line-height: 1.5; color: #1f2937; }
          h1 { font-size: 1.4rem; margin: 0 0 1.5rem; }
          .meta { background: #f3f4f6; padding: 1rem; border-radius: 0.5rem; margin: 1rem 0; font-size: 0.9rem; }
          .meta dt { font-weight: 600; margin-top: 0.5rem; }
          .meta dt:first-child { margin-top: 0; }
          .meta dd { margin: 0; word-break: break-all; font-family: ui-monospace, monospace; font-size: 0.85rem; }
          .actions { display: flex; gap: 0.5rem; margin-top: 1.5rem; }
          button { flex: 1; padding: 0.75rem 1rem; font-size: 1rem; border: 1px solid #d1d5db; border-radius: 0.375rem; cursor: pointer; }
          button.primary { background: #2563eb; color: white; border-color: #2563eb; }
          button.secondary { background: white; color: #1f2937; }
        </style>
      </head>
      <body>
        <h1>Authorize <strong><%= h(@client_name) %></strong>?</h1>
        <p>This application is requesting access to your account at this server.</p>
        <dl class="meta">
          <dt>Scope</dt>
          <dd><%= h(@scope) %></dd>
          <dt>Resource</dt>
          <dd><%= h(@resource) %></dd>
          <dt>Redirects to</dt>
          <dd><%= h(@redirect_uri) %></dd>
        </dl>
        <form method="POST" action="<%= h(@action_path) %>">
          <input type="hidden" name="_csrf_token" value="<%= h(@csrf_token) %>" />
          <input type="hidden" name="consent_request" value="<%= h(@consent_request) %>" />
          <div class="actions">
            <button type="submit" name="action" value="approve" class="primary">Approve</button>
            <button type="submit" name="action" value="deny" class="secondary">Deny</button>
          </div>
        </form>
      </body>
    </html>
    """,
    [:assigns]
  )

  @doc """
  Render the consent screen as a binary HTML body.
  """
  @spec render(:consent, map()) :: iodata()
  def render(:consent, assigns), do: render_consent(assigns)

  @doc false
  def h(value), do: Phoenix.HTML.html_escape(to_string(value)) |> Phoenix.HTML.safe_to_string()
end
