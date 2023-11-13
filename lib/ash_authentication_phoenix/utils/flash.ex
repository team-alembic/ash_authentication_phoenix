defmodule AshAuthentication.Phoenix.Utils.Flash do
  @moduledoc """
  Utility functions for sending and receiving flash messages.
  """

  import Phoenix.LiveView

  @doc """
  Attach a hook to receive flash messages sent from components, for rendering in
  the top-level liveview.
  """
  def on_mount(_name, _params, _session, socket) do
    {:cont, attach_hook(socket, :flash, :handle_info, &maybe_receive_flash/2)}
  end

  defp maybe_receive_flash({:put_flash, type, message}, socket) do
    {:halt, put_flash(socket, type, message)}
  end

  defp maybe_receive_flash(_, socket), do: {:cont, socket}

  @doc """
  Send flash messages from components, to be rendered in their parent liveview.
  """
  def put_flash!(socket, type, message) do
    send(self(), {:put_flash, type, message})
    socket
  end
end
