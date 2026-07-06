# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

# credo:disable-for-this-file Credo.Check.Design.AliasUsage
if Code.ensure_loaded?(Igniter) do
  defmodule AshAuthentication.Phoenix.Igniter do
    @moduledoc false
    # Shared Igniter helpers used by the installer and upgrader.

    @oauth_family ~w[oauth2 oidc github google auth0 apple slack microsoft okta dynamic_oidc]a

    @doc """
    Generates the "signing you in…" interstitial used for OAuth/OIDC providers
    that return the callback as a cross-site `response_mode=form_post` POST.

    Generates a renderer module, an editable EEx template, and the
    `:oauth2_interstitial_renderer` config — but only when a resource defines an
    OAuth/OIDC strategy. Idempotent, and a no-op otherwise.
    """
    @spec generate_oauth_interstitial(Igniter.t()) :: Igniter.t()
    def generate_oauth_interstitial(igniter) do
      {igniter, resources} = find_resources_with_oauth_strategies(igniter)

      if resources == [] do
        igniter
      else
        web_module = Igniter.Libs.Phoenix.web_module(igniter)

        igniter
        |> create_interstitial_renderer(web_module)
        |> create_interstitial_template(web_module)
        |> configure_interstitial_renderer(web_module)
      end
    end

    defp find_resources_with_oauth_strategies(igniter) do
      Igniter.Project.Module.find_all_matching_modules(igniter, fn _module, zipper ->
        case enter_auth_strategies(zipper) do
          {:ok, zipper} -> Enum.any?(@oauth_family, &has_strategy?(zipper, &1))
          _ -> false
        end
      end)
    end

    defp enter_auth_strategies(zipper) do
      with {:ok, zipper} <-
             Igniter.Code.Function.move_to_function_call_in_current_scope(
               zipper,
               :authentication,
               1
             ),
           {:ok, zipper} <- Igniter.Code.Common.move_to_do_block(zipper),
           {:ok, zipper} <-
             Igniter.Code.Function.move_to_function_call_in_current_scope(zipper, :strategies, 1) do
        Igniter.Code.Common.move_to_do_block(zipper)
      end
    end

    defp has_strategy?(zipper, strategy_type) do
      match?(
        {:ok, _},
        Igniter.Code.Function.move_to_function_call_in_current_scope(zipper, strategy_type, [1, 2])
      )
    end

    defp create_interstitial_renderer(igniter, web_module) do
      module = Module.concat(web_module, AuthInterstitialHTML)

      case Igniter.Project.Module.module_exists(igniter, module) do
        {true, igniter} ->
          igniter

        {false, igniter} ->
          Igniter.Project.Module.create_module(igniter, module, ~S'''
          @moduledoc """
          Renders the "signing you in…" interstitial shown while completing sign-in
          with an OAuth/OIDC provider that uses `response_mode=form_post` (e.g. Apple).

          The cross-site form_post callback can't read the session cookie, so this
          page re-POSTs the parameters same-origin, where the session is available.
          Edit `auth_interstitial_html/signing_in.html.eex` to customise it.
          """

          require EEx

          EEx.function_from_file(
            :def,
            :render,
            Path.join(__DIR__, "auth_interstitial_html/signing_in.html.eex"),
            [:assigns]
          )
          ''')
      end
    end

    defp create_interstitial_template(igniter, web_module) do
      module = Module.concat(web_module, AuthInterstitialHTML)

      template_path =
        igniter
        |> Igniter.Project.Module.proper_location(module)
        |> Path.rootname()
        |> Path.join("signing_in.html.eex")

      Igniter.create_new_file(igniter, template_path, interstitial_template(), on_exists: :skip)
    end

    defp configure_interstitial_renderer(igniter, web_module) do
      module = Module.concat(web_module, AuthInterstitialHTML)

      Igniter.Project.Config.configure_new(
        igniter,
        "config.exs",
        :ash_authentication,
        [:oauth2_interstitial_renderer],
        {module, :render}
      )
    end

    defp interstitial_template do
      """
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <meta name="robots" content="noindex, nofollow" />
          <title>Signing you in…</title>
        </head>
        <body onload="document.forms[0].submit()">
          <form method="post" action="<%= Plug.HTML.html_escape(@action) %>">
            <%= for {key, value} <- @params do %>
              <input type="hidden" name="<%= Plug.HTML.html_escape(to_string(key)) %>" value="<%= Plug.HTML.html_escape(to_string(value)) %>" />
            <% end %>
            <input type="hidden" name="<%= @reflected_param %>" value="1" />
            <noscript>
              <p>Signing you in…</p>
              <button type="submit">Continue</button>
            </noscript>
          </form>
          <p>Signing you in…</p>
        </body>
      </html>
      """
    end
  end
end
