# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

# credo:disable-for-this-file Credo.Check.Design.AliasUsage
if Code.ensure_loaded?(Igniter) do
  defmodule AshAuthentication.Phoenix.Igniter do
    @moduledoc false
    # Shared Igniter helpers used by the installer and upgrader.

    @oauth_family ~w[oauth2 oidc github google auth0 apple slack microsoft okta dynamic_oidc]a

    @router_assign :ash_authentication_phoenix_router

    @doc """
    Selects the Phoenix router to be modified, along with the web module it
    belongs to.

    The web module is read from the router's `use <WebModule>, :router`, so that
    generated modules are namespaced against the router they are wired into
    rather than against the application name. Falls back to the application's
    web module when there is no router to read.

    The answer is remembered for the rest of the run, so tasks composed together
    all generate into the same namespace and the user is only asked once.
    """
    @spec select_router_and_web_module(Igniter.t(), String.t()) ::
            {Igniter.t(), module() | nil, module()}
    def select_router_and_web_module(igniter, label) do
      case igniter.assigns[@router_assign] do
        {router, web_module} ->
          {igniter, router, web_module}

        nil ->
          {igniter, router} = Igniter.Libs.Phoenix.select_router(igniter, label)

          {igniter, web_module} =
            if router do
              Igniter.Libs.Phoenix.web_module_for_router(igniter, router)
            else
              {igniter, Igniter.Libs.Phoenix.web_module(igniter)}
            end

          {Igniter.assign(igniter, @router_assign, {router, web_module}), router, web_module}
      end
    end

    @doc """
    The `overrides:` option for generated routes: the app's own `AuthOverrides`
    module on top of the DaisyUI preset when the app vendors DaisyUI, the
    default preset otherwise.
    """
    @spec overrides_option(Igniter.t(), module()) :: String.t()
    def overrides_option(igniter, web_module) do
      base =
        if Igniter.exists?(igniter, "assets/vendor/daisyui.js") do
          AshAuthentication.Phoenix.Overrides.DaisyUI
        else
          AshAuthentication.Phoenix.Overrides.Default
        end

      "overrides: [#{inspect(Module.concat(web_module, AuthOverrides))}, #{inspect(base)}]"
    end

    @doc """
    Mounts the routes for the strategies and add-ons the user resource actually
    declares, skipping any the router already has:

    * a `password` strategy gets `reset_route`, plus `register_path` and
      `reset_path` on `sign_in_route`
    * a `confirmation` add-on gets `confirm_route`
    * a `magic_link` strategy gets `magic_sign_in_route`

    The routes serve the generated sign-in views, so nothing is added to a
    router without a `sign_in_route` — an app with its own views keeps them.
    Runs from `ash_authentication_phoenix.setup` once the base routes are in,
    and from each strategy's Phoenix task once the strategy is on the resource,
    so the router follows the resource whichever order they are set up in.
    """
    @spec ensure_strategy_routes(Igniter.t(), module(), module(), module()) :: Igniter.t()
    def ensure_strategy_routes(igniter, user, router, web_module) do
      {igniter, features} = authentication_features(igniter, user)

      if router && features != [] && generated_views?(igniter, router) do
        overrides = overrides_option(igniter, web_module)

        Enum.reduce(features, igniter, fn
          :password, igniter ->
            igniter
            |> add_sign_in_paths(router)
            |> add_route(router, :reset_route, """
            reset_route auth_routes_prefix: "/auth", #{overrides}
            """)

          {:confirmation, name}, igniter ->
            add_route(igniter, router, :confirm_route, """
            confirm_route #{inspect(user)}, #{inspect(name)},
              auth_routes_prefix: "/auth",
              #{overrides}
            """)

          {:magic_link, name}, igniter ->
            add_route(igniter, router, :magic_sign_in_route, """
            magic_sign_in_route #{inspect(user)}, #{inspect(name)},
              auth_routes_prefix: "/auth",
              #{overrides}
            """)
        end)
      else
        igniter
      end
    end

    # What the user resource declares, read off its source: `:password`,
    # `{:confirmation, name}` and `{:magic_link, name}`.
    defp authentication_features(igniter, user) do
      with {:ok, {igniter, _source, zipper}} <- Igniter.Project.Module.find_module(igniter, user),
           {:ok, zipper} <- Igniter.Code.Common.move_to_do_block(zipper) do
        {igniter, Enum.flat_map(features(), &find_feature(zipper, &1))}
      else
        {:error, igniter} -> {igniter, []}
        :error -> {igniter, []}
      end
    end

    # `{section, entry, default name}` for each strategy or add-on with routes.
    defp features do
      [
        {:strategies, :password, nil},
        {:add_ons, :confirmation, nil},
        {:strategies, :magic_link, :magic_link}
      ]
    end

    defp find_feature(zipper, {section, type, default}) do
      case find_entry(zipper, section, type) do
        {:ok, _entry} when type == :password -> [:password]
        {:ok, entry} -> [{type, entry_name(entry, default)}]
        :error -> []
      end
    end

    defp find_entry(zipper, section, type) do
      with {:ok, zipper} <- enter_authentication_section(zipper, section) do
        Igniter.Code.Function.move_to_function_call_in_current_scope(zipper, type, [1, 2])
      end
    end

    # `magic_link :remember_me do` is named; `magic_link do` takes the default.
    defp entry_name(zipper, default) do
      with {:ok, zipper} <- Igniter.Code.Function.move_to_nth_argument(zipper, 0),
           {:ok, name} when is_atom(name) <- Igniter.Code.Common.expand_literal(zipper) do
        name
      else
        _ -> default
      end
    end

    defp generated_views?(igniter, router) do
      {_igniter, _source, zipper} = Igniter.Project.Module.find_module!(igniter, router)
      has_call?(zipper, :sign_in_route, [0, 1])
    end

    defp has_call?(zipper, name, arities) do
      match?({:ok, _}, Igniter.Code.Function.move_to_function_call(zipper, name, arities))
    end

    # Right after `sign_in_route`, so the routes for the generated views sit
    # together; `sign_in_route` is there, or nothing would be added at all.
    defp add_route(igniter, router, name, code) do
      Igniter.Project.Module.find_and_update_module!(igniter, router, fn zipper ->
        with false <- has_call?(zipper, name, [0, 1, 2, 3]),
             {:ok, zipper} <-
               Igniter.Code.Function.move_to_function_call(zipper, :sign_in_route, [0, 1]) do
          {:ok, Igniter.Code.Common.add_code(zipper, code, placement: :after)}
        else
          _ -> {:ok, zipper}
        end
      end)
    end

    # The password strategy's registration and reset pages hang off
    # `sign_in_route`; paths already set by hand are kept.
    defp add_sign_in_paths(igniter, router) do
      Igniter.Project.Module.find_and_update_module!(igniter, router, fn zipper ->
        case Igniter.Code.Function.move_to_function_call(zipper, :sign_in_route, [0, 1]) do
          {:ok, zipper} -> set_sign_in_paths(zipper)
          :error -> {:ok, zipper}
        end
      end)
    end

    @sign_in_paths [register_path: "/register", reset_path: "/reset"]

    defp set_sign_in_paths(zipper) do
      if Igniter.Code.Function.function_call?(zipper, :sign_in_route, 0) do
        Igniter.Code.Function.append_argument(zipper, @sign_in_paths)
      else
        Igniter.Code.Function.update_nth_argument(
          zipper,
          0,
          &set_keyword_keys(&1, @sign_in_paths)
        )
      end
    end

    defp set_keyword_keys(zipper, pairs) do
      Enum.reduce_while(pairs, {:ok, zipper}, fn {key, value}, {:ok, zipper} ->
        case Igniter.Code.Keyword.set_keyword_key(zipper, key, value) do
          {:ok, zipper} -> {:cont, {:ok, zipper}}
          other -> {:halt, other}
        end
      end)
    end

    defp enter_authentication_section(zipper, section) do
      with {:ok, zipper} <-
             Igniter.Code.Function.move_to_function_call_in_current_scope(
               zipper,
               :authentication,
               1
             ),
           {:ok, zipper} <- Igniter.Code.Common.move_to_do_block(zipper),
           {:ok, zipper} <-
             Igniter.Code.Function.move_to_function_call_in_current_scope(zipper, section, 1) do
        Igniter.Code.Common.move_to_do_block(zipper)
      end
    end

    @doc """
    Points the sign-in page at the local Swoosh mailbox preview in dev.

    `mix phx.new` forwards `/dev/mailbox` to `Plug.Swoosh.MailboxPreview`, so
    the generated senders deliver into a mailbox the developer can actually
    open. Configuring the path makes
    `AshAuthentication.Phoenix.Components.SignIn` render a link to it.

    Only call this when a Swoosh mailer has been found — without one nothing is
    being delivered locally. Existing configuration is left alone.
    """
    @spec configure_dev_mailbox(Igniter.t()) :: Igniter.t()
    def configure_dev_mailbox(igniter) do
      Igniter.Project.Config.configure_new(
        igniter,
        "dev.exs",
        :ash_authentication,
        [:dev_mailbox_path],
        "/dev/mailbox"
      )
    end

    @doc """
    Generates the "signing you in…" interstitial used for OAuth/OIDC providers
    that return the callback as a cross-site `response_mode=form_post` POST.

    Generates a renderer module, an editable EEx template, and the
    `:oauth2_interstitial_renderer` config — but only when a resource defines an
    OAuth/OIDC strategy. Idempotent, and a no-op otherwise.
    """
    @spec generate_oauth_interstitial(Igniter.t(), module()) :: Igniter.t()
    def generate_oauth_interstitial(igniter, web_module) do
      {igniter, resources} = find_resources_with_oauth_strategies(igniter)

      if resources == [] do
        igniter
      else
        igniter
        |> create_interstitial_renderer(web_module)
        |> create_interstitial_template(web_module)
        |> configure_interstitial_renderer(web_module)
        |> ensure_csrf_skip_plug()
      end
    end

    # OAuth `form_post` callbacks are cross-site POSTs with no CSRF token (OAuth
    # `state` is the CSRF defence). Prepend the skip plug to each router's
    # `:browser` pipeline so it runs before `:protect_from_forgery`. Only affects
    # POSTs to callback paths; every other request stays CSRF-protected.
    defp ensure_csrf_skip_plug(igniter) do
      {igniter, routers} = Igniter.Libs.Phoenix.list_routers(igniter)

      Enum.reduce(routers, igniter, fn router, igniter ->
        case Igniter.Libs.Phoenix.has_pipeline(igniter, router, :browser) do
          {igniter, true} ->
            Igniter.Libs.Phoenix.prepend_to_pipeline(
              igniter,
              :browser,
              "plug :skip_csrf_for_oauth_callback",
              router: router
            )

          {igniter, false} ->
            igniter
        end
      end)
    end

    defp find_resources_with_oauth_strategies(igniter) do
      Igniter.Project.Module.find_all_matching_modules(igniter, fn _module, zipper ->
        case enter_authentication_section(zipper, :strategies) do
          {:ok, zipper} -> Enum.any?(@oauth_family, &has_strategy?(zipper, &1))
          _ -> false
        end
      end)
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
      <%!--
        This is a plain EEx template, not HEEx, so nothing is escaped automatically.
        The assigns carry the OAuth/OIDC provider's response parameters, which arrive
        straight from the request, so wrap every interpolation you add in
        `Plug.HTML.html_escape/1` as the existing ones below do.
      --%>
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
            <input type="hidden" name="<%= Plug.HTML.html_escape(@reflected_param) %>" value="1" />
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
