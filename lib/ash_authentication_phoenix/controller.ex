# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Controller do
  @moduledoc """
  The authentication controller generator.

  Since authentication often requires explicit HTTP requests to do things like
  set cookies or return Authorization headers, use this module to create an
  `AuthController` in your Phoenix application.

  ## Example

  Handling the registration or authentication of a normal web-based user.

  ```elixir
  defmodule MyAppWeb.AuthController do
    use MyAppWeb, :controller
    use AshAuthentication.Phoenix.Controller

    def success(conn, _activity, user, token) do
      conn
      |> store_in_session(user)
      |> assign(:current_user, user)
      |> set_live_socket_id(token)
      |> redirect(to: Routes.page_path(conn, :index))
    end

    def failure(conn, _activity, _reason) do
      conn
      |> put_status(401)
      |> render("failure.html")
    end

    def sign_out(conn, _params) do
      conn
      |> clear_session()
      |> render("sign_out.html")
    end
  end
  ```

  Handling registration or authentication of an API user.

  ```elixir
  defmodule MyAppWeb.ApiAuthController do
    use MyAppWeb, :controller
    use AshAuthentication.Phoenix.Controller
    alias AshAuthentication.TokenRevocation

    def success(conn, _activity, _user, token) do
      conn
      |> put_status(200)
      |> json(%{
        authentication: %{
          status: :success,
          bearer: token}
      })
    end

    def failure(conn, _activity, _reason) do
      conn
      |> put_status(401)
      |> json(%{
        authentication: %{
          status: :failed
        }
      })
    end

    def sign_out(conn, _params) do
      conn
      |> revoke_bearer_tokens()
      |> json(%{
        status: :ok
      })
    end
  end
  ```

  """

  alias AshAuthentication.Plug.Dispatcher
  alias AshAuthentication.Plug.Helpers

  alias AshAuthentication.TokenResource.Info
  alias AshAuthentication.Jwt
  alias Plug.Conn

  @type t :: module

  @type activity :: {strategy_name :: atom, phase :: atom}
  @type user :: Ash.Resource.record() | nil
  @type token :: String.t() | nil

  @doc """
  Called when authentication (or registration, depending on the provider) has been successful.
  """
  @callback success(Conn.t(), activity, user, token) :: Conn.t()

  @doc """
  Called when authentication fails.
  """
  @callback failure(Conn.t(), activity, reason :: any) :: Conn.t()

  @doc """
  Called when a request to sign out is received.
  """
  @callback sign_out(Conn.t(), params :: map) :: Conn.t()

  @doc false
  @spec __using__(any) :: Macro.t()
  defmacro __using__(_opts) do
    quote do
      @behaviour AshAuthentication.Phoenix.Controller
      @behaviour AshAuthentication.Plug
      import Phoenix.Controller
      import Plug.Conn, except: [clear_session: 1]
      import AshAuthentication.Phoenix.Plug
      import AshAuthentication.Phoenix.Controller

      @doc false
      @impl true
      @spec success(
              Conn.t(),
              AshAuthentication.Phoenix.Controller.activity(),
              AshAuthentication.Phoenix.Controller.user(),
              AshAuthentication.Phoenix.Controller.token()
            ) ::
              Conn.t()
      def success(conn, _activity, user, _token) do
        conn
        |> store_in_session(user)
        |> put_status(200)
        |> render("success.html")
      end

      @doc false
      @impl true
      @spec failure(Conn.t(), AshAuthentication.Phoenix.Controller.activity(), reason :: any) ::
              Conn.t()
      def failure(conn, _activity, _reason) do
        conn
        |> put_status(401)
        |> render("failure.html")
      end

      @doc false
      @impl true
      @spec call(Conn.t(), any) :: Conn.t()
      def call(%{private: %{strategy: strategy}} = conn, {_subject_name, _stategy_name, phase}) do
        conn
        |> Dispatcher.call({phase, strategy, __MODULE__})
      end

      def call(conn, opts) do
        super(conn, opts)
      end

      @doc false
      @impl true
      @spec handle_success(
              Conn.t(),
              AshAuthentication.Phoenix.Controller.activity(),
              AshAuthentication.Phoenix.Controller.user(),
              AshAuthentication.Phoenix.Controller.token()
            ) :: Conn.t()
      def handle_success(conn, activity, user, token) do
        conn
        |> put_private(:phoenix_action, :success)
        |> put_private(:success_args, [activity, user, token])
        |> call(:success)
      end

      @doc false
      @impl true
      @spec handle_failure(Conn.t(), AshAuthentication.Phoenix.Controller.activity(), any) ::
              Conn.t()
      def handle_failure(conn, activity, reason) do
        conn
        |> put_private(:phoenix_action, :failure)
        |> put_private(:failure_args, [activity, reason])
        |> call(:failure)
      end

      @doc false
      @spec action(Conn.t(), any) :: Conn.t()
      def action(conn, opts) do
        conn
        |> action_name()
        |> case do
          :success ->
            args = Map.get(conn.private, :success_args, [nil, nil, nil])
            apply(__MODULE__, :success, [conn | args])

          :failure ->
            args = Map.get(conn.private, :failure_args, [nil, nil])
            apply(__MODULE__, :failure, [conn | args])

          _ ->
            super(conn, opts)
        end
      end

      defoverridable success: 4, failure: 3
    end
  end

  defmacro clear_session(_conn) do
    raise """
    Using clear_session/1 in your `auth_controller` is deprecated. Please use `clear_session/2` instead,
    passing the conn and the otp_app.

    For example:

        conn
        |> clear_session(conn, :my_app)


    This ensures that session tokens & bearer tokens are revoked on logout.

    If you wish to retain the old behavior (not advised), call `Plug.Conn.clear_session/1` directly.
    """
  end

  @doc """
  Clears the session and revokes bearer and session tokens.

  This ensures that session tokens & bearer tokens are revoked on logout.
  """
  def clear_session(conn, otp_app) do
    conn
    |> Helpers.revoke_bearer_tokens(otp_app)
    |> Helpers.revoke_session_tokens(otp_app)
    |> Plug.Conn.clear_session()
  end

  @doc """
  Set the live socket id so we can send disconnects from the server when the token is revoked.

  This ensures that the user can't use the application with revoked tokens.
  """
  def set_live_socket_id(conn, token) do
    with {:ok, claims} <- Jwt.peek(token),
         otp_app <- conn.private.phoenix_endpoint.config(:otp_app),
         {:ok, resource} <- Jwt.token_to_resource(token, otp_app),
         {:ok, token_resource} <-
           AshAuthentication.Info.authentication_tokens_token_resource(resource),
         {:ok, template_fn} <-
           Info.token_live_socket_id_template(token_resource) do
      conn
      |> Plug.Conn.put_session(:live_socket_id, template_fn.(claims))
    else
      _ -> conn
    end
  end
end
