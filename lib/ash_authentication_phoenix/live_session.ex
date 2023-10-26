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

  import Phoenix.Component, only: [assign: 2, assign: 3, assign_new: 3]
  import AshAuthentication.Phoenix.Components.Helpers
  alias AshAuthentication.{Info, Phoenix.LiveSession}
  alias Phoenix.LiveView.Socket

  @doc """
  Generate a live session wherein all subject assigns are copied from the conn
  into the socket.

  Options:
    * `:otp_app` - Set the otp app in which to search for authenticated resources.

  All other options are passed through to `live_session`, but with session and on_mount hooks
  added to set assigns for authenticated resources. Unlike `live_session`, this supports
  multiple MFAs provided for the `session` option. The produced sessions will be merged.
  """
  @spec ash_authentication_live_session(atom, opts :: Keyword.t()) :: Macro.t()
  defmacro ash_authentication_live_session(session_name \\ :ash_authentication, opts \\ [],
             do: block
           ) do
    quote do
      on_mount = [LiveSession]

      opts = unquote(opts)

      session = {LiveSession, :generate_session, [opts[:otp_app], List.wrap(opts[:session])]}

      opts =
        opts
        |> Keyword.update(:on_mount, on_mount, &(on_mount ++ List.wrap(&1)))
        |> Keyword.put(:session, session)

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
    tenant = session["tenant"]

    socket = assign(socket, current_tenant: tenant)

    socket =
      socket
      |> otp_app_from_socket()
      |> AshAuthentication.authenticated_resources()
      |> Stream.map(&{to_string(Info.authentication_subject_name!(&1)), &1})
      |> Enum.reduce(socket, fn {subject_name, resource}, socket ->
        current_subject_name = String.to_existing_atom("current_#{subject_name}")

        if Map.has_key?(socket.assigns, current_subject_name) do
          raise "Cannot set assign `#{current_subject_name}` before default `AshAuthentication.Phoenix.LiveSession.on_mount/4` has run."
        end

        assign_new(socket, current_subject_name, fn ->
          if value = session[subject_name] do
            # credo:disable-for-next-line Credo.Check.Refactor.Nesting
            case AshAuthentication.subject_to_user(value, resource, tenant: tenant) do
              {:ok, user} -> user
              _ -> nil
            end
          end
        end)
      end)

    {:cont, socket}
  end

  def on_mount(_, _params, _session, socket), do: {:cont, socket}

  @doc """
  Supplements the session with any `current_X` assigns which are authenticated
  resource records from the conn.
  """
  @spec generate_session(Plug.Conn.t(), atom | [atom], additional_hooks :: [mfa]) :: %{
          required(String.t()) => String.t()
        }
  def generate_session(conn, otp_app \\ nil, additional_hooks \\ []) do
    otp_app = otp_app || conn.assigns[:otp_app] || conn.private.phoenix_endpoint.config(:otp_app)

    acc =
      Enum.reduce(additional_hooks, %{}, fn {m, f, a}, acc ->
        Map.merge(acc, apply(m, f, [conn | a]) || %{})
      end)

    otp_app
    |> AshAuthentication.authenticated_resources()
    |> Stream.map(&{to_string(Info.authentication_subject_name!(&1)), &1})
    |> Enum.reduce(acc, fn {subject_name, resource}, session ->
      case Map.fetch(
             conn.assigns,
             String.to_existing_atom("current_#{subject_name}")
           ) do
        {:ok, user} when is_struct(user, resource) ->
          session
          |> Map.put(subject_name, AshAuthentication.user_to_subject(user))
          |> Map.put("tenant", Ash.PlugHelpers.get_tenant(conn))

        _ ->
          session
          |> Map.put("tenant", Ash.PlugHelpers.get_tenant(conn))
      end
    end)
  end
end
