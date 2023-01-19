defmodule AshAuthentication.Phoenix.LiveSession do
  @moduledoc """
  Ensures that any loaded users which are present in a conn's assigns are also
  present in a live view socket's assigns.

  Typical usage is via the `ash_authentication_live_session/2` macro, but can also
  manually called like so:

  ```elixir
  scope "/", ExampleWeb do
    pipe_through(:browser)

    live_session :authenticated, on_mount: LiveSession, session: {LiveSession, :session, []} do
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
  """
  @spec ash_authentication_live_session(atom, opts :: Keyword.t()) :: Macro.t()
  defmacro ash_authentication_live_session(session_name \\ :ash_authentication, opts \\ [], block_opts \\ []) do
    {block, opts} =
      case opts do
        [do: opts_block] when block_opts == [] ->
          {opts_block, Keyword.delete(opts, :do)}

        _ ->
          {block_opts[:do], opts}
      end

    quote do
      on_mount= LiveSession
      session = {LiveSession, :generate_session, []}
      opts =
        unquote(opts)
        |> Keyword.update(:on_mount, on_mount, &([on_mount | List.wrap(&1)]))
        |> Keyword.update(:session, session, &([session | List.wrap(&1)]))

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
  @spec on_mount(atom, %{required(String.t()) => any}, %{required(String.t()) => any}, Socket.t()) ::
          {:cont | :halt, Socket.t()}
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
             {:ok, user} <- AshAuthentication.subject_to_user(value, resource),
             {:ok, subject_name} <- Info.authentication_subject_name(resource) do
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
  @spec generate_session(Plug.Conn.t()) :: %{required(String.t()) => String.t()}
  def generate_session(conn) do
    otp_app = conn.private.phoenix_endpoint.config(:otp_app)

    otp_app
    |> AshAuthentication.authenticated_resources()
    |> Stream.map(&{to_string(Info.authentication_subject_name!(&1)), &1})
    |> Enum.reduce(%{}, fn {subject_name, resource}, session ->
      case Map.fetch(conn.assigns, String.to_existing_atom("current_#{subject_name}")) do
        {:ok, user} when is_struct(user, resource) ->
          Map.put(session, subject_name, AshAuthentication.user_to_subject(user))

        _ ->
          session
      end
    end)
  end
end
