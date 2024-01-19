defmodule DevWeb.CustomSignInLive do
  @moduledoc false
  use Phoenix.LiveView

  alias AshAuthentication.{Phoenix.Components.Password, Info}
  alias Phoenix.LiveView.{Rendered, Socket}
  import PhoenixHTMLHelpers.Form

  @doc false
  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign_new(:strategy, fn -> Info.strategy!(Example.Accounts.User, :password) end)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)

    {:ok, socket}
  end

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t() | no_return
  def render(assigns) do
    ~H"""
    <div class="grid h-screen place-items-center dark:bg-gray-900">
      <.live_component
        module={Password}
        strategy={@strategy}
        id="custom-password"
        socket={@socket}
        overrides={@overrides}
        class="mx-auth w-full max-w-sm lg:w-96"
      >
        <:sign_in_extra :let={form}>
          <div class="mt-2 mb-2 dark:text-white">
            <%= label(form, :capcha,
              class: "block text-sm font-medium text-gray-700 mb-1 dark:text-white"
            ) %>
            <%= text_input(form, :capcha,
              class:
                "appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-blue-pale-500 focus:border-blue-pale-500 sm:text-sm dark:text-black"
            ) %>
          </div>
        </:sign_in_extra>

        <:register_extra :let={form}>
          <div class="mt-2 mb-2 dark:text-white">
            <%= label(form, :name,
              class: "block text-sm font-medium text-gray-700 mb-1 dark:text-white"
            ) %>
            <%= text_input(form, :name,
              class:
                "appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-blue-pale-500 focus:border-blue-pale-500 sm:text-sm dark:text-black"
            ) %>
          </div>
        </:register_extra>

        <:reset_extra :let={form}>
          <div class="mt-2 mb-2 dark:text-white">
            <%= label(form, :capcha,
              class: "block text-sm font-medium text-gray-700 mb-1 dark:text-white"
            ) %>
            <%= text_input(form, :capcha,
              class:
                "appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-blue-pale-500 focus:border-blue-pale-500 sm:text-sm dark:text-black"
            ) %>
          </div>
        </:reset_extra>
      </.live_component>
    </div>
    """
  end
end
