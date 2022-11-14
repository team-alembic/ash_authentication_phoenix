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

    def success(conn, user, _token) do
      conn
      |> store_in_session(user)
      |> assign(:current_user, user)
      |> redirect(to: Routes.page_path(conn, :index))
    end

    def failure(conn, _reason) do
      conn
      |> put_status(401)
      |> render("failure.html")
    end

    def sign_out(conn) do
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

    def success(conn, _user, token) do
      conn
      |> put_status(200)
      |> json(%{
        authentication: %{
          status: :success,
          bearer: token}
      })
    end

    def failure(conn, _reason) do
      conn
      |> put_status(401)
      |> json(%{
        authentication: %{
          status: :failed
        }
      })
    end

    def sign_out(conn) do
      conn
      |> revoke_bearer_tokens()
      |> json(%{
        status: :ok
      })
    end
  end
  ```

  """

  @typedoc false
  @type routes :: %{
          required({String.t(), String.t()}) => %{
            required(:provider) => module,
            optional(atom) => any
          }
        }

  alias Plug.Conn
  @doc false
  @callback request(Conn.t(), %{required(String.t()) => String.t()}) :: Conn.t()

  @doc false
  @callback callback(Conn.t(), %{required(String.t()) => String.t()}) :: Conn.t()

  @doc """
  Called when authentication (or registration, depending on the provider) has been successful.
  """
  @callback success(Conn.t(), user :: Ash.Resource.record(), token :: String.t()) :: Conn.t()

  @doc """
  Called when authentication fails.
  """
  @callback failure(Conn.t(), nil | Ash.Changeset.t() | Ash.Error.t()) :: Conn.t()

  @doc """
  Called when a request to sign out is received.
  """
  @callback sign_out(Conn.t(), map) :: Conn.t()

  @doc false
  @spec __using__(any) :: Macro.t()
  defmacro __using__(_opts) do
    quote do
      @behaviour AshAuthentication.Phoenix.Controller
      import Phoenix.Controller
      import Plug.Conn
      import AshAuthentication.Phoenix.Plug

      @doc false
      @impl true
      @spec request(Conn.t(), map) :: Conn.t()
      def request(conn, params),
        do:
          AshAuthentication.Phoenix.Controller.request(
            conn,
            params,
            __MODULE__
          )

      @doc false
      @impl true
      @spec callback(Conn.t(), map) :: Conn.t()
      def callback(conn, params),
        do:
          AshAuthentication.Phoenix.Controller.callback(
            conn,
            params,
            __MODULE__
          )

      @doc false
      @impl true
      @spec success(Conn.t(), Ash.Resource.record(), nil | AshAuthentication.Jwt.token()) ::
              Conn.t()
      def success(conn, user, _token) do
        conn
        |> store_in_session(user)
        |> put_status(200)
        |> render("success.html")
      end

      @doc false
      @impl true
      @spec failure(Conn.t(), nil | Ash.Changeset.t() | Ash.Error.t()) :: Conn.t()
      def failure(conn, _) do
        conn
        |> put_status(401)
        |> render("failure.html")
      end

      @doc false
      @impl true
      @spec sign_out(Conn.t(), map) :: Conn.t()
      def sign_out(conn, _params) do
        conn
        |> clear_session()
        |> render("sign_out.html")
      end

      defoverridable success: 3, failure: 2, sign_out: 2
    end
  end

  @doc false
  @spec request(Conn.t(), %{required(String.t()) => String.t()}, module) :: Conn.t()
  def request(conn, params, return_to) do
    handle(conn, params, :request, return_to)
  end

  @doc false
  @spec callback(Conn.t(), %{required(String.t()) => String.t()}, module) :: Conn.t()
  def callback(conn, params, return_to) do
    handle(conn, params, :callback, return_to)
  end

  defp handle(conn, _params, phase, return_to) do
    conn
    |> generate_routes()
    |> dispatch(phase, conn)
    |> return(return_to)
  end

  defp dispatch(
         routes,
         phase,
         %{params: %{"subject_name" => subject_name, "provider" => provider}} = conn
       ) do
    case Map.get(routes, {subject_name, provider}) do
      config when is_map(config) ->
        conn = Conn.put_private(conn, :authenticator, config)

        case phase do
          :request -> config.provider.request_plug(conn, [])
          :callback -> config.provider.callback_plug(conn, [])
        end

      _ ->
        conn
    end
  end

  defp dispatch(_routes, _phase, conn), do: conn

  defp return(
         %{
           private: %{
             authentication_result: {:success, user},
             authenticator: %{resource: resource}
           }
         } = conn,
         return_to
       )
       when is_struct(user, resource),
       do: return_to.success(conn, user, Map.get(user.__metadata__, :token))

  defp return(%{private: %{authentication_result: {:success, nil}}} = conn, return_to),
    do: return_to.success(conn, nil, nil)

  defp return(%{private: %{authentication_result: {:failure, reason}}} = conn, return_to),
    do: return_to.failure(conn, reason)

  defp return(conn, return_to), do: return_to.failure(conn, nil)

  # Doing this on every request is probably a really bad idea, but if I do it at
  # compile time I need to ask for the OTP app all over the place and it reduces
  # the developer experience sharply.
  #
  # Maybe we should just shove them in ETS?
  defp generate_routes(conn) do
    :otp_app
    |> conn.private.phoenix_endpoint.config()
    |> AshAuthentication.authenticated_resources()
    |> Stream.flat_map(fn config ->
      subject_name =
        config.subject_name
        |> to_string()

      config
      |> Map.get(:providers, [])
      |> Stream.map(fn provider ->
        config =
          config
          |> Map.delete(:providers)
          |> Map.put(:provider, provider)

        {{subject_name, provider.provides(config.resource)}, config}
      end)
    end)
    |> Map.new()
  end
end
