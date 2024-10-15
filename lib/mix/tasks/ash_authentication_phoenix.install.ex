# credo:disable-for-this-file Credo.Check.Design.AliasUsage
# credo:disable-for-this-file Credo.Check.Readability.TrailingWhiteSpace
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
        yes: :boolean
      ],
      composes: ["ash_authentication.install"],
      aliases: [
        a: :accounts,
        u: :user,
        t: :token,
        y: :yes
      ]
    }
  end

  def igniter(igniter, argv) do
    options = options!(argv)

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
      !Igniter.Project.Deps.get_dependency_declaration(igniter, :ash_authentication)

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
              yes: options[:yes]
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

      igniter
      |> Igniter.Project.Formatter.import_dep(:ash_authentication_phoenix)
      |> Igniter.compose_task("igniter.add_extension", ["phoenix"])
      |> warn_on_missing_modules(options, argv, install?)
      |> explain_tailwind_changes()
      |> use_authentication_phoenix_router(router)
      |> create_auth_controller()
      |> create_overrides_module(overrides)
      |> Igniter.Libs.Phoenix.append_to_pipeline(:browser, "plug :load_from_session",
        router: router
      )
      |> Igniter.Libs.Phoenix.append_to_pipeline(:api, "plug :load_from_bearer", router: router)
      |> Igniter.Libs.Phoenix.append_to_scope(
        "/",
        """
        auth_routes AuthController, #{inspect(options[:user])}, path: "/auth"
        sign_out_route AuthController

        # Remove these if you'd like to use your own authentication views
        sign_in_route register_path: "/register", reset_path: "/reset", auth_routes_prefix: "/auth", on_mount: [{#{inspect(web_module)}.LiveUserAuth, :live_no_user}],
          overrides: [#{inspect(overrides)}, AshAuthentication.Phoenix.Overrides.Default]

        # Remove this if you do not want to use the reset password feature
        reset_route auth_routes_prefix: "/auth"
        """,
        with_pipelines: [:browser],
        arg2: Igniter.Libs.Phoenix.web_module(igniter),
        router: router
      )
      |> setup_live_view(router, web_module)
    else
      igniter
      |> Igniter.add_warning("""
      AshAuthenticationPhoenix installer could not find a Phoenix router. Skipping installation.

      Set up a phoenix router and reinvoke the installer with `mix igniter.install ash_authentication_phoenix`.
      """)
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
    #  set :show_banner false
    # end
    """)
  end

  defp setup_live_view(igniter, router, web_module) do
    igniter
    |> create_live_user_auth(web_module)
    |> add_live_session_scopes(web_module, router)
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
    Igniter.Project.Module.create_module(
      igniter,
      Igniter.Libs.Phoenix.web_module_name(igniter, "LiveUserAuth"),
      """
      @moduledoc \"\"\"
      Helpers for authenticating users in LiveViews.
      \"\"\"

      import Phoenix.Component
      use #{inspect(web_module)}, :verified_routes

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

  defp create_auth_controller(igniter) do
    Igniter.Project.Module.create_module(
      igniter,
      Igniter.Libs.Phoenix.web_module_name(igniter, "AuthController"),
      """
      use #{inspect(Igniter.Libs.Phoenix.web_module(igniter))}, :controller
      use AshAuthentication.Phoenix.Controller

      def success(conn, _activity, user, _token) do
        return_to = get_session(conn, :return_to) || ~p"/"

        conn
        |> delete_session(:return_to)
        |> store_in_session(user)
        # If your resource has a different name, update the assign name here (i.e :current_admin)
        |> assign(:current_user, user)
        |> redirect(to: return_to)
      end

      def failure(conn, _activity, _reason) do
        conn
        |> put_flash(:error, "Incorrect email or password")
        |> redirect(to: ~p"/sign-in")
      end

      def sign_out(conn, _params) do
        return_to = get_session(conn, :return_to) || ~p"/"

        conn
        |> clear_session()
        |> redirect(to: return_to)
      end
      """
    )
  end

  defp use_authentication_phoenix_router(igniter, router) do
    Igniter.Project.Module.find_and_update_module!(igniter, router, fn zipper ->
      with {:ok, zipper} <- Igniter.Libs.Phoenix.move_to_router_use(igniter, zipper) do
        {:ok, Igniter.Code.Common.add_code(zipper, "use AshAuthentication.Phoenix.Router")}
      end
    end)
  end

  defp explain_tailwind_changes(igniter) do
    Igniter.add_notice(igniter, """
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
        Keyword.put(opts, name, Igniter.Code.Module.parse(value))

      _ ->
        opts
    end
  end
end
