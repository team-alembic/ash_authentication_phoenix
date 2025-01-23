defmodule AshAuthentication.Phoenix.Test.Helper do
  @moduledoc false

  @doc "Send message to original test (to simulate user/email interaction)"
  # copied from Swoosh
  def notify_test(message) do
    pids =
      Enum.uniq([self() | List.wrap(Process.get(:"$callers"))])

    for pid <- pids do
      send(pid, message)
    end
  end
end
