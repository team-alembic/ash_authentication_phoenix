# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

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

  import Phoenix.Component, only: [assign: 3, assign_new: 3]
  import AshAuthentication.Phoenix.Components.Helpers
  alias AshAuthentication.{Info, Jwt, Phoenix.LiveSession, TokenResource.Actions}
  alias Phoenix.LiveView.Socket

  @doc """
  Assigns all subjects from their equivalent sessions, if they are not already assigned.

  This exists to power nested liveviews, which have the session available but
  do not automatically inherit any assigns.

  This does verify the token and confirm that it is not expired, but it
  bypasses the check for the token's presence in the token resource, even if
  you have configured AshAuthentication to
  `require_token_presence_for_authentication?`. This is because nested live views
  do not need to check *again* for this, as the `:load_from_session` plug already
  does this.
  """
  @spec assign_new_resources(socket :: Phoenix.Socket.t(), session :: map()) :: Phoenix.Socket.t()
  def assign_new_resources(socket, session, opts \\ []) do
    otp_app =
      opts[:otp_app] || AshAuthentication.Phoenix.Components.Helpers.otp_app_from_socket(socket)

    AshAuthentication.Plug.Helpers.assign_new_resources(
      socket,
      session,
      &Phoenix.Component.assign_new/3,
      Keyword.put_new(opts, :otp_app, otp_app)
    )
  end

  @doc """
  Generate a live session wherein all subject assigns are copied from the conn
  into the socket.

  Options:
    * `:otp_app` - Set the otp app in which to search for authenticated resources.
    * `:on_mount_prepend` - Same as `:on_mount`, but for hooks that need to be
      run before AshAuthenticationPhoenix's hooks.

  All other options are passed through to `live_session`, but with session and on_mount hooks
  added to set assigns for authenticated resources. Unlike `live_session`, this supports
  multiple MFAs provided for the `session` option. The produced sessions will be merged.
  """
  @spec ash_authentication_live_session(atom, opts :: Keyword.t()) :: Macro.t()
  defmacro ash_authentication_live_session(session_name \\ :ash_authentication, opts \\ [],
             do: block
           ) do
    opts =
      if Macro.quoted_literal?(opts) do
        Macro.prewalk(opts, &expand_alias(&1, __CALLER__))
      else
        opts
      end

    quote generated: true do
      opts = unquote(opts)
      opts = LiveSession.opts(opts)

      require Phoenix.LiveView.Router

      # credo:disable-for-next-line Credo.Check.Design.AliasUsage
      Phoenix.LiveView.Router.live_session unquote(session_name), opts do
        unquote(block)
      end
    end
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:mount, 3}})

  defp expand_alias(other, _env), do: other

  @doc """
  Get options that should be passed to `live_session`.

  This is useful for integrating with other tools that require a custom `live_session`,
  like `beacon_live_admin`. For example:

  ```elixir
  beacon_live_admin AshAuthentication.Phoenix.LiveSession.opts(...beacon_opts) do
    ...
  end
  ```
  """
  def opts(custom_opts \\ []) do
    on_mount = [LiveSession]

    session =
      {__MODULE__, :generate_session, [custom_opts[:otp_app], List.wrap(custom_opts[:session])]}

    opts =
      custom_opts
      |> Keyword.update(:on_mount, on_mount, &(on_mount ++ List.wrap(&1)))
      |> Keyword.put(:session, session)

    {otp_app, opts} = Keyword.pop(opts, :otp_app)

    opts =
      if otp_app do
        Keyword.update!(opts, :on_mount, &[{LiveSession, {:set_otp_app, otp_app}} | &1])
      else
        opts
      end

    {on_mount_prepend, opts} = Keyword.pop(opts, :on_mount_prepend)

    if on_mount_prepend do
      Keyword.update!(opts, :on_mount, &(List.wrap(on_mount_prepend) ++ &1))
    else
      opts
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
    tenant = socket.assigns[:current_tenant] || session["tenant"]

    socket =
      if tenant do
        assign_new(socket, :current_tenant, fn -> tenant end)
      else
        socket
      end

    context = session["context"] || %{}
    opts = [tenant: tenant, context: context]

    otp_app =
      socket
      |> otp_app_from_socket()

    otp_app
    |> AshAuthentication.authenticated_resources()
    |> Stream.map(
      &{&1, Info.authentication_tokens_require_token_presence_for_authentication?(&1),
       to_string(Info.authentication_subject_name!(&1))}
    )
    |> Enum.reduce_while(socket, fn
      {resource, true, subject_name}, socket ->
        current_subject_name = String.to_existing_atom("current_#{subject_name}")
        token_resource = Info.authentication_tokens_token_resource!(resource)
        session_key = "#{subject_name}_token"

        with token when is_binary(token) <-
               session[session_key],
             {:ok, %{"sub" => subject, "jti" => jti} = claims, _}
             when not is_map_key(claims, "act") <- Jwt.verify(token, otp_app, opts),
             {:ok, [_]} <-
               Actions.get_token(token_resource, %{"jti" => jti, "purpose" => "user"}, opts) do
          {:cont, assign_user(socket, current_subject_name, subject, resource, opts)}
        else
          _ ->
            {:cont, socket}
        end

      {resource, false, subject_name}, socket ->
        current_subject_name = String.to_existing_atom("current_#{subject_name}")

        with subject when is_binary(subject) <- session[subject_name],
             {:ok, subject} <- split_identifier(subject, resource) do
          {:cont, assign_user(socket, current_subject_name, subject, resource, opts)}
        else
          _ ->
            {:cont, socket}
        end
    end)
    |> then(&{:cont, &1})
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
          |> Map.put("context", Ash.PlugHelpers.get_context(conn))

        _ ->
          session
          |> Map.put("tenant", Ash.PlugHelpers.get_tenant(conn))
          |> Map.put("context", Ash.PlugHelpers.get_context(conn))
      end
    end)
  end

  defp assign_user(socket, current_subject_name, subject, resource, opts) do
    assign_new(socket, current_subject_name, fn ->
      case AshAuthentication.subject_to_user(
             subject,
             resource,
             opts
           ) do
        {:ok, user} -> user
        _ -> nil
      end
    end)
  end

  # shamelessly copied from AshAuthentication.Plugs.Helpers
  defp split_identifier(subject, resource) do
    if Info.authentication_session_identifier!(resource) == :jti do
      case String.split(subject, ":", parts: 2) do
        [_jti, subject] -> {:ok, subject}
        _ -> :error
      end
    else
      {:ok, subject}
    end
  end
end
