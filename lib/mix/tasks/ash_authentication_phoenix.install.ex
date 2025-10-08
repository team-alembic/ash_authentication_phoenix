# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

# credo:disable-for-this-file Credo.Check.Design.AliasUsage
# credo:disable-for-this-file Credo.Check.Readability.TrailingWhiteSpace
if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshAuthenticationPhoenix.Install do
    use Igniter.Mix.Task

    @example "mix igniter.install ash_authentication_phoenix"

    @shortdoc "Installs AshAuthenticationPhoenix. Invoke with `mix igniter.install ash_authentication_phoenix`"
    @moduledoc """
    #{@shortdoc}

    ## Example

    ```bash
    #{@example}
    ```

    ## Options

    * `--accounts` or `-a` - The domain that contains your resources. Defaults to `YourApp.Accounts`.
    * `--user` or `-u` - The resource that represents a user. Defaults to `<accounts>.User`.
    * `--token` or `-t` - The resource that represents a token. Defaults to `<accounts>.Token`.
    """

    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        example: @example,
        group: :ash,
        schema: [
          accounts: :string,
          user: :string,
          token: :string,
          yes: :boolean,
          auth_strategy: :string
        ],
        composes: ["ash_authentication.install"],
        aliases: [
          s: :auth_strategy,
          a: :accounts,
          u: :user,
          t: :token,
          y: :yes
        ]
      }
    end

    def igniter(igniter) do
      options = igniter.args.options
      argv = igniter.args.argv

      options =
        Keyword.put_new_lazy(options, :accounts, fn ->
          Igniter.Project.Module.module_name(igniter, "Accounts")
        end)

      options =
        options
        |> Keyword.put_new_lazy(:user, fn ->
          Module.concat(options[:accounts], User)
        end)
        |> Keyword.put_new_lazy(:token, fn ->
          Module.concat(options[:accounts], Token)
        end)
        |> module_option(:user)
        |> module_option(:accounts)
        |> module_option(:token)

      install? =
        !match?({:ok, _}, Igniter.Project.Deps.get_dep(igniter, :ash_authentication))

      igniter =
        if install? do
          igniter
          |> Igniter.Project.Deps.add_dep({:ash_authentication, "~> 4.1"}, yes: options[:yes])
          |> then(fn
            %{assigns: %{test_mode?: true}} = igniter ->
              igniter

            igniter ->
              Igniter.apply_and_fetch_dependencies(igniter,
                error_on_abort?: true,
                yes: options[:yes],
                yes_to_deps: true
              )
          end)
          |> Igniter.compose_task("ash_authentication.install", argv)
        else
          igniter
        end

      {igniter, router} =
        Igniter.Libs.Phoenix.select_router(
          igniter,
          "Which Phoenix router should be modified to allow authentication?"
        )

      if router do
        web_module = Igniter.Libs.Phoenix.web_module(igniter)
        overrides = Igniter.Libs.Phoenix.web_module_name(igniter, "AuthOverrides")
        otp_app = Igniter.Project.Application.app_name(igniter)

        igniter
        |> Igniter.Project.Formatter.import_dep(:ash_authentication_phoenix)
        |> Igniter.compose_task("igniter.add_extension", ["phoenix"])
        |> setup_routes_alias()
        |> warn_on_missing_modules(options, argv, install?)
        |> do_or_explain_tailwind_changes()
        |> create_auth_controller(otp_app)
        |> create_overrides_module(overrides)
        |> add_auth_routes(overrides, options, router, web_module)
        |> create_live_user_auth(web_module)
      else
        igniter
        |> Igniter.add_warning("""
        AshAuthenticationPhoenix installer could not find a Phoenix router. Skipping installation.

        Set up a phoenix router and reinvoke the installer with `mix igniter.install ash_authentication_phoenix`.
        """)
      end
    end

    def setup_routes_alias(igniter) do
      # if `Phoenix.Router` is not loaded we don't
      # know what version they are using and conservatively
      # do not add an alias that will cause an error
      if Code.ensure_loaded?(Phoenix.Router) do
        # Phoenix >= 1.8 uses the new formatted routes feature and
        # so we do not need this alias
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
        |> Igniter.Libs.Phoenix.append_to_pipeline(:browser, "plug :load_from_session",
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
        |> add_live_session_scopes(web_module, router)
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

        def success(conn, activity, user, _token) do
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

              _ ->
                "Incorrect email or password"
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

             import AshAuthentication.Plug.Helpers
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

    defp warn_on_missing_modules(igniter, options, argv, install?) do
      with {:accounts, {true, igniter}} <-
             {:accounts, Igniter.Project.Module.module_exists(igniter, options[:accounts])},
           {:user, {true, igniter}} <-
             {:user, Igniter.Project.Module.module_exists(igniter, options[:user])},
           {:token, {true, igniter}} <-
             {:token, Igniter.Project.Module.module_exists(igniter, options[:token])} do
        igniter
      else
        {type, {false, igniter}} ->
          if install? do
            Igniter.add_issue(
              igniter,
              "Could not find #{type} module: #{inspect(options[type])}. Something went wrong with installing ash_authentication."
            )
          else
            run_installer? =
              Mix.shell().yes?("""
              Could not find #{type} module. Please set the equivalent CLI flag.

              There are two likely causes:

              1. You have an existing #{type} module that does not have the default name.
                  If this is the case, quit this command and use the
                  --#{type} flag to specify the correct module.
              2. You have not yet run the `ash_authentication` installer.
                  To run this, answer Y to this prompt.

              Run the installer now?
              """)

            if run_installer? do
              Igniter.compose_task(igniter, "ash_authentication.install", argv)
            else
              igniter
            end
          end
      end
    end

    defp module_option(opts, name) do
      case Keyword.fetch(opts, name) do
        {:ok, value} when is_binary(value) ->
          Keyword.put(opts, name, Igniter.Project.Module.parse(value))

        _ ->
          opts
      end
    end
  end
else
  defmodule Mix.Tasks.AshAuthenticationPhoenix.Install do
    use Mix.Task

    @shortdoc "Installs AshAuthenticationPhoenix. Invoke with `mix igniter.install ash_authentication_phoenix`"

    @moduledoc @shortdoc

    def run(_argv) do
      Mix.shell().error("""
      The task 'ash_authentication_phoenix.install' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
