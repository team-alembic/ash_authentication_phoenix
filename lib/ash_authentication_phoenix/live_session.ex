defmodule AshAuthentication.Phoenix.LiveSession do
  @moduledoc """
  Ensures that any loaded users which are present in a conn's assigns are also
  present in a live view socket's assigns.

  Typical usage is via the `authenticated_session/3` macro, but can also
  manually called like so:

  ```elixir
  pipeline :browser do
    # ...
    plug :load_from_session
  end

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
  alias Plug.Conn

  defmacro authenticated_session(subject_name \\ nil, opts \\ [], do: block) do
    IO.inspect(subject_name: subject_name, opts: opts, block: block)

    {on_mount, session} =
      case subject_name do
        nil -> {:default, []}
        other -> {other, [other]}
      end
      |> Macro.escape()

    block =
      if Keyword.get(opts, :required) && subject_name do
        quote do
          pipeline unquote(:"#{subject_name}_required") do
            # import AshAuthentication.Plug.Assertions
            # plug :require, unquote(subject_name)
          end

          scope "/" do
            pipe_through unquote(:"#{subject_name}_required")
            unquote(block)
          end
        end
      else
        block
      end

    quote do
      live_session(:authenticated,
        on_mount: {LiveSession, unquote(on_mount)},
        session: {LiveSession, :session, unquote(session)}
      ) do
        unquote(block)
      end
    end
  end

  @doc """
  Hooks a live view's lifecycle to ensure that any authenticated users loaded in
  the conn are carried over to the liveview socket's assigns.

  It expects to find a list of subjects in the `"ash_authentication_subjects"`
  key of the session map.

  See `session/1` for information on how to generate these.
  """
  @spec on_mount(atom, %{required(String.t()) => any}, %{required(String.t()) => any}, Socket.t()) ::
          {:cont | :halt, Socket.t()}
  def on_mount(:default, _params, %{"ash_authentication_subjects" => subjects}, socket) do
    otp_app = otp_app_from_socket(socket)

    resources =
      otp_app
      |> AshAuthentication.authenticated_resources()
      |> Stream.map(&{to_string(Info.authentication_subject_name!(&1)), &1})
      |> Map.new()

    socket =
      resources
      |> Enum.reduce(socket, fn {subject_name, _}, socket ->
        assign(socket, String.to_existing_atom("current_#{subject_name}"), nil)
      end)

    socket =
      subjects
      |> Enum.reduce(socket, fn subject, socket ->
        subject = URI.parse(subject)

        with {:ok, resource} <- Map.fetch(resources, subject.path),
             {:ok, user} <- AshAuthentication.subject_to_user(subject, resource),
             {:ok, subject_name} <- Info.authentication_subject_name(resource) do
          assign(socket, String.to_existing_atom("current_#{subject_name}"), user)
        else
          _ -> socket
        end
      end)

    {:cont, socket}
  end

  def on_mount(subject_name, _params, %{"ash_authentication_subjects" => [subject]}, socket) do
    otp_app = otp_app_from_socket(socket)
    current_subject_name = String.to_existing_atom("current_#{subject_name}")

    with {:ok, resource} <- find_resource_by_subject_name(subject_name, otp_app),
         {:ok, user} <- AshAuthentication.subject_to_user(subject, resource) do
      assign(socket, current_subject_name, user)
    else
      _ -> assign(socket, current_subject_name, nil)
    end
  end

  def on_mount(_, _params, _session, socket), do: {:cont, socket}

  @doc """
  Given a Plug connection with the subjects loaded into the assigns, generate
  some liveview session params which can be loaded.
  """
  @spec session(Conn.t(), atom) :: %{required(String.t()) => any}
  def session(conn, subject_name \\ nil)

  def session(conn, nil) do
    otp_app = conn.private.phoenix_endpoint.config(:otp_app)
    authenticated_resources = AshAuthentication.authenticated_resources(otp_app)

    subjects =
      conn.assigns
      |> Stream.filter(&String.starts_with?(to_string(elem(&1, 0)), "current_"))
      |> Stream.map(&elem(&1, 1))
      |> Stream.filter(&is_struct(&1))
      |> Stream.filter(&(&1.__struct__ in authenticated_resources))
      |> Enum.map(&AshAuthentication.user_to_subject/1)

    %{"ash_authentication_subjects" => subjects}
  end

  def session(conn, subject_name) do
    otp_app = conn.private.phoenix_endpoint.config(:otp_app)

    with {:ok, resource} <- find_resource_by_subject_name(subject_name, otp_app),
         user when is_struct(user, resource) <-
           Map.get(conn.assigns, String.to_existing_atom("current_#{subject_name}")),
         subject <- AshAuthentication.user_to_subject(user) do
      %{"ash_authentication_subjects" => [subject]}
    else
      _ -> %{"ash_authentication_subjects" => []}
    end
  end

  defp find_resource_by_subject_name(subject_name, otp_app) do
    otp_app
    |> AshAuthentication.authenticated_resources()
    |> Enum.find(&(Info.authentication_subject_name!(&1) == subject_name))
    |> case do
      nil -> :error
      resource -> {:ok, resource}
    end
  end
end
