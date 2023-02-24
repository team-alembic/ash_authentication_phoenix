defmodule AshAuthentication.Phoenix.LiveSession do
  @moduledoc """
  Ensures that any loaded users which are present in a conn's assigns are also
  present in a live view socket's assigns.

  Typical usage is via the `ash_authentication_live_session/2` macro, but can also
  manually called like so:

  ```elixir
  scope "/", ExampleWeb do
    pipe_through(:browser)

    live_session :authenticated, on_mount: LiveSession, session: {LiveSession, :generate_session, []} do
      live "/", ExampleLive
    end
  end
  ```
  """

  import Phoenix.Component, only: [assign: 3]
  import AshAuthentication.Phoenix.Components.Helpers
  alias AshAuthentication.{Info, Phoenix.LiveSession}
  alias Phoenix.LiveView.Socket

  @doc """
  Generate a live session wherein all subject assigns are copied from the conn
  into the socket.

  Options:
    * `:otp_app` - Set the otp app in which to search for authenticated resources.

  All other options are passed through to `live_session`, but with session and on_mount hooks
  added to set assigns for authenticated resources.
  """
  @spec ash_authentication_live_session(atom, opts :: Keyword.t()) :: Macro.t()
  defmacro ash_authentication_live_session(session_name \\ :ash_authentication, opts \\ [],
             do: block
           ) do
    quote do
      on_mount = [LiveSession]

      opts = unquote(opts)

      session = {LiveSession, :generate_session, [opts[:otp_app]]}

      opts =
        opts
        |> Keyword.update(:on_mount, on_mount, &(on_mount ++ List.wrap(&1)))
        |> Keyword.update(:session, session, &[session | List.wrap(&1)])

      {otp_app, opts} = Keyword.pop(opts, :otp_app)

      opts =
        if otp_app do
          Keyword.update!(opts, :on_mount, &[{LiveSession, {:set_otp_app, otp_app}} | &1])
        else
          opts
        end

      live_session unquote(session_name), opts do
        unquote(block)
      end
    end
  end

  @doc """
  Inspects the incoming session for any subject_name -> subject values and loads
  them into the socket's assigns.

  For example a session containing `{"user",
  "user?id=aa6c179c-ee75-4d49-8796-528c2981b396"}` becomes an assign called
  `current_user` with the loaded user as the value.
  """
  @spec on_mount(
          atom | {:set_otp_app, atom},
          %{required(String.t()) => any},
          %{required(String.t()) => any},
          Socket.t()
        ) ::
          {:cont | :halt, Socket.t()}
  def on_mount({:set_otp_app, otp_app}, _params, _, socket) do
    {:cont, assign(socket, :otp_app, otp_app)}
  end

  def on_mount(:default, _params, session, socket) do
    otp_app = otp_app_from_socket(socket)

    resources =
      otp_app
      |> AshAuthentication.authenticated_resources()
      |> Stream.map(&{to_string(Info.authentication_subject_name!(&1)), &1})
      |> Map.new()

    socket =
      session
      |> Enum.reduce(socket, fn {key, value}, socket ->
        with {:ok, resource} <- Map.fetch(resources, key),
             {:ok, user} <-
               AshAuthentication.subject_to_user(value, resource),
             {:ok, subject_name} <-
               Info.authentication_subject_name(resource) do
          assign(socket, String.to_existing_atom("current_#{subject_name}"), user)
        else
          _ -> socket
        end
      end)

    {:cont, socket}
  end

  def on_mount(_, _params, _session, socket), do: {:cont, socket}

  @doc """
  Supplements the session with any `current_X` assigns which are authenticated
  resource records from the conn.
  """
  @spec generate_session(Plug.Conn.t(), atom | [atom]) :: %{required(String.t()) => String.t()}
  def generate_session(conn, otp_app \\ nil) do
    otp_app = otp_app || conn.assigns[:otp_app] || conn.private.phoenix_endpoint.config(:otp_app)

    otp_app
    |> AshAuthentication.authenticated_resources()
    |> Stream.map(&{to_string(Info.authentication_subject_name!(&1)), &1})
    |> Enum.reduce(%{}, fn {subject_name, resource}, session ->
      case Map.fetch(
             conn.assigns,
             String.to_existing_atom("current_#{subject_name}")
           ) do
        {:ok, user} when is_struct(user, resource) ->
          Map.put(session, subject_name, AshAuthentication.user_to_subject(user))

        _ ->
          session
      end
    end)
  end
end
