# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

# credo:disable-for-this-file Credo.Check.Design.AliasUsage
if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshAuthenticationPhoenix.Setup do
    use Igniter.Mix.Task

    @example "mix ash_authentication_phoenix.setup"

    @shortdoc "Ensures Phoenix authentication infrastructure (routes, controller, sign-in page) exists"

    @moduledoc """
    #{@shortdoc}

    This task is idempotent and safe to run multiple times. It ensures the following
    exist in your Phoenix application:

    * `use AshAuthentication.Phoenix.Router` in your router
    * An `AuthController` for handling authentication callbacks
    * A `LiveUserAuth` module for LiveView authentication
    * An `AuthOverrides` module for customising authentication UI
    * Authentication routes (`auth_routes`, `sign_in_route`, `sign_out_route`)
    * Pipeline plugs for session and bearer token loading
    * Tailwind CSS configuration for authentication components

    This task is composed automatically when adding OAuth/OIDC strategies via
    `mix ash_authentication_phoenix.add_strategy`.

    ## Example

    ```bash
    #{@example}
    ```

    ## Options

    * `--user`, `-u` - The user resource. Defaults to `YourApp.Accounts.User`
    * `--accounts`, `-a` - The accounts domain. Defaults to `YourApp.Accounts`
    """

    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :ash,
        example: @example,
        extra_args?: false,
        only: nil,
        positional: [],
        composes: [],
        schema: [
          accounts: :string,
          user: :string
        ],
        aliases: [
          a: :accounts,
          u: :user
        ]
      }
    end

    def igniter(igniter) do
      options = parse_options(igniter)

      {igniter, router} =
        Igniter.Libs.Phoenix.select_router(
          igniter,
          "Which Phoenix router should be modified for authentication?"
        )

      if router do
        web_module = Igniter.Libs.Phoenix.web_module(igniter)
        overrides = Igniter.Libs.Phoenix.web_module_name(igniter, "AuthOverrides")
        otp_app = Igniter.Project.Application.app_name(igniter)

        igniter
        |> Igniter.Project.Formatter.import_dep(:ash_authentication_phoenix)
        |> Igniter.compose_task("igniter.add_extension", ["phoenix"])
        |> setup_routes_alias()
        |> do_or_explain_tailwind_changes()
        |> create_auth_controller(otp_app)
        |> create_overrides_module(overrides)
        |> create_live_user_auth(web_module)
        |> add_auth_routes(overrides, options, router, web_module)
        |> add_live_session_scopes(web_module, router)
      else
        Igniter.add_warning(igniter, """
        Could not find a Phoenix router. Skipping authentication UI setup.

        Set up a Phoenix router and re-run this task.
        """)
      end
    end

    defp parse_options(igniter) do
      options =
        igniter.args.options
        |> Keyword.put_new_lazy(:accounts, fn ->
          Igniter.Project.Module.module_name(igniter, "Accounts")
        end)

      options
      |> Keyword.put_new_lazy(:user, fn ->
        Module.concat(options[:accounts], User)
      end)
      |> Keyword.update!(:accounts, &maybe_parse_module/1)
      |> Keyword.update!(:user, &maybe_parse_module/1)
    end

    defp maybe_parse_module(value) when is_binary(value), do: Igniter.Project.Module.parse(value)
    defp maybe_parse_module(value), do: value

    # Extracted from ash_authentication_phoenix.install — identical logic

    def setup_routes_alias(igniter) do
      if Code.ensure_loaded?(Phoenix.Router) do
        if function_exported?(Phoenix.Router, :__formatted_routes__, 1) do
          igniter
        else
          Igniter.Project.TaskAliases.add_alias(
            igniter,
            "phx.routes",
            ["phx.routes", "ash_authentication.phoenix.routes"],
            if_exists: {:append, "ash_authentication.phoenix.routes"}
          )
        end
      else
        igniter
      end
    end

    defp add_auth_routes(igniter, overrides, options, router, web_module) do
      with {_, _source, zipper} <- Igniter.Project.Module.find_module!(igniter, router),
           {:ok, zipper} <- Igniter.Code.Common.move_to_do_block(zipper),
           :error <- Igniter.Code.Module.move_to_use(zipper, AshAuthentication.Phoenix.Router) do
        override_module =
          if Igniter.exists?(igniter, "assets/vendor/daisyui.js") do
            AshAuthentication.Phoenix.Overrides.DaisyUI
          else
            AshAuthentication.Phoenix.Overrides.Default
          end

        igniter
        |> use_authentication_phoenix_router(router)
        |> Igniter.Libs.Phoenix.append_to_pipeline(
          :browser,
          "plug :load_from_session\nplug :set_actor, :user",
          router: router
        )
        |> Igniter.Libs.Phoenix.append_to_pipeline(
          :api,
          "plug :load_from_bearer\nplug :set_actor, :user",
          router: router
        )
        |> add_to_graphql_pipeline(router)
        |> Igniter.Libs.Phoenix.append_to_scope(
          "/",
          """
          auth_routes AuthController, #{inspect(options[:user])}, path: "/auth"
          sign_out_route AuthController

          # Remove these if you'd like to use your own authentication views
          sign_in_route register_path: "/register", reset_path: "/reset", auth_routes_prefix: "/auth", on_mount: [{#{inspect(web_module)}.LiveUserAuth, :live_no_user}],
            overrides: [#{inspect(overrides)}, #{override_module}]

          # Remove this if you do not want to use the reset password feature
          reset_route auth_routes_prefix: "/auth", overrides: [#{inspect(overrides)}, #{override_module}]

          # Remove this if you do not use the confirmation strategy
          confirm_route #{inspect(options[:user])},
            :confirm_new_user,
            auth_routes_prefix: "/auth",
            overrides: [#{inspect(overrides)}, #{override_module}]

          # Remove this if you do not use the magic link strategy.
          magic_sign_in_route #{inspect(options[:user])},
            :magic_link,
            auth_routes_prefix: "/auth",
            overrides: [#{inspect(overrides)}, #{override_module}]
          """,
          with_pipelines: [:browser],
          arg2: Igniter.Libs.Phoenix.web_module(igniter),
          router: router
        )
      else
        _ ->
          igniter
      end
    end

    defp add_to_graphql_pipeline(igniter, router) do
      case Igniter.Libs.Phoenix.has_pipeline(igniter, router, :graphql) do
        {igniter, true} ->
          Igniter.Libs.Phoenix.prepend_to_pipeline(
            igniter,
            :graphql,
            "plug :load_from_bearer\nplug :set_actor, :user",
            router: router
          )

        {igniter, _} ->
          igniter
      end
    end

    defp create_overrides_module(igniter, name) do
      Igniter.Project.Module.create_module(igniter, name, """
      use AshAuthentication.Phoenix.Overrides

      # configure your UI overrides here

      # First argument to `override` is the component name you are overriding.
      # The body contains any number of configurations you wish to override
      # Below are some examples

      # For a complete reference, see https://hexdocs.pm/ash_authentication_phoenix/ui-overrides.html

      # override AshAuthentication.Phoenix.Components.Banner do
      #   set :image_url, "https://media.giphy.com/media/g7GKcSzwQfugw/giphy.gif"
      #   set :text_class, "bg-red-500"
      # end

      # override AshAuthentication.Phoenix.Components.SignIn do
      #  set :show_banner, false
      # end
      """)
    end

    defp add_live_session_scopes(igniter, web_module, router) do
      {_, _source, zipper} = Igniter.Project.Module.find_module!(igniter, router)

      case Igniter.Code.Common.move_to(zipper, fn zipper ->
             Igniter.Code.Function.function_call?(zipper, :ash_authentication_live_session, [
               1,
               2,
               3,
               4
             ])
           end) do
        {:ok, _} ->
          igniter

        :error ->
          Igniter.Libs.Phoenix.add_scope(
            igniter,
            "/",
            """
            pipe_through :browser

            ash_authentication_live_session :authenticated_routes do
              # in each liveview, add one of the following at the top of the module:
              #
              # If an authenticated user must be present:
              # on_mount {#{inspect(web_module)}.LiveUserAuth, :live_user_required}
              #
              # If an authenticated user *may* be present:
              # on_mount {#{inspect(web_module)}.LiveUserAuth, :live_user_optional}
              #
              # If an authenticated user must *not* be present:
              # on_mount {#{inspect(web_module)}.LiveUserAuth, :live_no_user}
            end
            """,
            arg2: Igniter.Libs.Phoenix.web_module(igniter),
            router: router
          )
      end
    end

    defp create_live_user_auth(igniter, web_module) do
      live_user_auth = Igniter.Libs.Phoenix.web_module_name(igniter, "LiveUserAuth")

      Igniter.Project.Module.create_module(
        igniter,
        live_user_auth,
        """
        @moduledoc \"\"\"
        Helpers for authenticating users in LiveViews.
        \"\"\"

        import Phoenix.Component
        use #{inspect(web_module)}, :verified_routes

        # This is used for nested liveviews to fetch the current user.
        # To use, place the following at the top of that liveview:
        # on_mount {#{inspect(live_user_auth)}, :current_user}
        def on_mount(:current_user, _params, session, socket) do
          {:cont, AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)}
        end

        def on_mount(:live_user_optional, _params, _session, socket) do
          if socket.assigns[:current_user] do
            {:cont, socket}
          else
            {:cont, assign(socket, :current_user, nil)}
          end
        end

        def on_mount(:live_user_required, _params, _session, socket) do
          if socket.assigns[:current_user] do
            {:cont, socket}
          else
            {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
          end
        end

        def on_mount(:live_no_user, _params, _session, socket) do
          if socket.assigns[:current_user] do
            {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
          else
            {:cont, assign(socket, :current_user, nil)}
          end
        end
        """
      )
    end

    defp create_auth_controller(igniter, otp_app) do
      Igniter.Project.Module.create_module(
        igniter,
        Igniter.Libs.Phoenix.web_module_name(igniter, "AuthController"),
        """
        use #{inspect(Igniter.Libs.Phoenix.web_module(igniter))}, :controller
        use AshAuthentication.Phoenix.Controller

        def success(conn, activity, user, token) do
          return_to = get_session(conn, :return_to) || ~p"/"

          message =
            case activity do
              {:confirm_new_user, :confirm} -> "Your email address has now been confirmed"
              {:password, :reset} -> "Your password has successfully been reset"
              _ -> "You are now signed in"
            end

          conn
          |> delete_session(:return_to)
          |> store_in_session(user)
          |> set_live_socket_id(token)
          # If your resource has a different name, update the assign name here (i.e :current_admin)
          |> assign(:current_user, user)
          |> put_flash(:info, message)
          |> redirect(to: return_to)
        end

        def failure(conn, activity, reason) do
          message =
            case {activity, reason} do
              {_,
              %AshAuthentication.Errors.AuthenticationFailed{
                caused_by: %Ash.Error.Forbidden{
                  errors: [%AshAuthentication.Errors.CannotConfirmUnconfirmedUser{}]
                }
              }} ->
                \"\"\"
                You have already signed in another way, but have not confirmed your account.
                You can confirm your account using the link we sent to you, or by resetting your password.
                \"\"\"

              {{:password, _}, _} ->
                "Incorrect email or password"

              {{:magic_link, _}, _} ->
                "Invalid or expired sign-in link"

              _ ->
                "Authentication failed"
            end

          conn
          |> put_flash(:error, message)
          |> redirect(to: ~p"/sign-in")
        end

        def sign_out(conn, _params) do
          return_to = get_session(conn, :return_to) || ~p"/"

          conn
          |> clear_session(:#{otp_app})
          |> put_flash(:info, "You are now signed out")
          |> redirect(to: return_to)
        end
        """
      )
    end

    defp use_authentication_phoenix_router(igniter, router) do
      Igniter.Project.Module.find_and_update_module!(igniter, router, fn zipper ->
        case Igniter.Libs.Phoenix.move_to_router_use(igniter, zipper) do
          {:ok, zipper} ->
            {:ok,
             Igniter.Code.Common.add_code(zipper, """
             use AshAuthentication.Phoenix.Router
             """)}

          _ ->
            {:ok, zipper}
        end
      end)
    end

    @tailwind_prefix """
    module.exports = {
      content: [
    """

    defp do_or_explain_tailwind_changes(igniter) do
      cond do
        Igniter.exists?(igniter, "assets/tailwind.config.js") ->
          igniter = Igniter.include_glob(igniter, "assets/tailwind.config.js")
          source = Rewrite.source!(igniter.rewrite, "assets/tailwind.config.js")
          content = Rewrite.Source.get(source, :content)

          if String.contains?(content, "ash_authentication_phoenix") do
            igniter
          else
            do_tailwind_v3_changes(igniter, content, source)
          end

        Igniter.exists?(igniter, "assets/css/app.css") ->
          igniter = Igniter.include_glob(igniter, "assets/css/app.css")
          source = Rewrite.source!(igniter.rewrite, "assets/css/app.css")
          content = Rewrite.Source.get(source, :content)

          if String.contains?(content, "ash_authentication_phoenix") do
            igniter
          else
            do_tailwind_v4_changes(igniter, content, source)
          end

        true ->
          explain_tailwind_changes(igniter)
      end
    end

    defp do_tailwind_v3_changes(igniter, content, source) do
      case String.split(content, @tailwind_prefix, parts: 2) do
        [prefix, suffix] ->
          insert = "    \"../deps/ash_authentication_phoenix/**/*.*ex\",\n"

          source =
            Rewrite.Source.update(
              source,
              :content,
              prefix <> @tailwind_prefix <> insert <> suffix
            )

          %{igniter | rewrite: Rewrite.update!(igniter.rewrite, source)}

        _ ->
          explain_tailwind_changes(igniter)
      end
    end

    defp do_tailwind_v4_changes(igniter, content, source) do
      with true <- String.contains?(content, "@import \"tailwindcss\""),
           [head, after_import] <-
             String.split(content, "@import \"tailwindcss\"", parts: 2),
           [import_stuff, after_import] <- String.split(after_import, "\n", parts: 2) do
        updated_content =
          head <>
            "@import \"tailwindcss\"#{import_stuff}\n" <>
            "@source \"../../deps/ash_authentication_phoenix\";\n" <> after_import

        source = Rewrite.Source.update(source, :content, updated_content)
        %{igniter | rewrite: Rewrite.update!(igniter.rewrite, source)}
      else
        _ ->
          explain_tailwind_changes(igniter)
      end
    end

    defp explain_tailwind_changes(igniter) do
      Igniter.add_notice(igniter, """
      AshAuthenticationPhoenix:

      If you are configuring Tailwind with a `tailwind.config.js` file
      (Tailwind 3 and below, maybe Tailwind 4):

        Modify your `tailwind.config.js` file, to add the ash_authentication_phoenix
        files to the `content` option.

          module.exports = {
            content: [
              "./js/**/*.js",
              "../lib/*_web.ex",
              "../lib/*_web/**/*.*ex",
              "../deps/ash_authentication_phoenix/**/*.*ex", // <-- Add this line
            ],
            ...
          }

      If you are configuring Tailwind with CSS (Tailwind 4):

        Add the following to your app.css file.

          @source "../../deps/ash_authentication_phoenix";
      """)
    end
  end
else
  defmodule Mix.Tasks.AshAuthenticationPhoenix.Setup do
    @shortdoc "Ensures Phoenix authentication infrastructure exists"

    @moduledoc @shortdoc

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'ash_authentication_phoenix.setup' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
