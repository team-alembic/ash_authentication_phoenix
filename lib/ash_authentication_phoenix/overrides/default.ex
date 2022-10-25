defmodule AshAuthentication.Phoenix.Overrides.Default do
  @moduledoc """
  The default implmentation of `AshAuthentication.Phoenix.Overrides` using
  [TailwindCSS](https://tailwindcss.com/).

  These colours and styles were chosen to be reasonably generic looking.
  """

  use AshAuthentication.Phoenix.Overrides

  @doc false
  @impl true
  def password_authentication_form_label_css_class,
    do: "block text-sm font-medium text-gray-700 mb-1"

  @doc false
  @impl true
  def password_authentication_form_input_surround_css_class, do: "mt-2 mb-2"

  @doc false
  @impl true
  def password_authentication_form_text_input_css_class,
    do: """
    appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md
    shadow-sm placeholder-gray-400 focus:outline-none focus:ring-blue-pale-500
    focus:border-blue-pale-500 sm:text-sm
    """

  @doc false
  @impl true
  def password_authentication_form_h2_css_class,
    do: "mt-2 mb-2 text-2xl tracking-tight font-bold text-gray-900"

  @doc false
  @impl true
  def password_authentication_form_submit_css_class,
    do: """
    w-full flex justify-center py-2 px-4 border border-transparent rounded-md
    shadow-sm text-sm font-medium text-white bg-blue-500
    hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-offset-2
    focus:ring-blue-500 mt-2 mb-4
    """

  @doc false
  @impl true
  def password_authentication_box_css_class, do: "mt-4 mb-4"

  @doc false
  @impl true
  def password_authentication_box_spacer_css_class,
    do: "w-full text-center font-semibold text-gray-400 uppercase text-lg"

  @doc false
  @impl true
  def password_authentication_form_error_ul_css_class, do: "text-red-700 font-light"

  @doc false
  @impl true
  def sign_in_box_css_class,
    do: "flex-1 flex flex-col justify-center py-12 px-4 sm:px-6 lg:flex-none lg:px-20 xl:px-24"

  @doc false
  @impl true
  def sign_in_row_css_class, do: "mx-auth w-full max-w-sm lg:w-96"

  @doc false
  @impl true
  def sign_in_live_css_class, do: "grid place-items-center"
end
