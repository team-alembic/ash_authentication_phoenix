defmodule AshAuthentication.Phoenix.TokenRevocationNotifier do
  use Ash.Notifier
  alias AshAuthentication.TokenResource.Info
  require Logger

  def notify(%Ash.Notifier.Notification{
        data: %{subject: "user"}
      }),
      do: :ok

  def notify(%Ash.Notifier.Notification{
        data: data,
        resource: token_resource
      }) do
    with {:ok, template_fn} <- Info.token_live_socket_id_template(token_resource),
         socket_id <- template_fn.(data),
         {:ok, endpoints} when endpoints != [] <- Info.token_endpoints(token_resource) do
      endpoints |> Enum.each(&apply(&1, :broadcast, [socket_id, "disconnect", %{}]))
    end
  end
end
