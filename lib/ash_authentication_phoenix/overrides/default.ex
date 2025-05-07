defmodule AshAuthentication.Phoenix.Overrides.Default do
  @moduledoc """
  This is the default overrides for our component UI.

  The CSS styles are based on [TailwindCSS](https://tailwindcss.com/).
  """

  use AshAuthentication.Phoenix.Overrides

  alias AshAuthentication.Phoenix.{
    Components,
    ConfirmLive,
    MagicSignInLive,
    ResetLive,
    SignInLive
  }

  override SignInLive do
    set :root_class, "grid h-screen place-items-center dark:bg-gray-900"
  end

  override ConfirmLive do
    set :root_class, "grid h-screen place-items-center dark:bg-gray-900"
  end

  override Components.Confirm do
    set :root_class, """
    flex-1 flex flex-col justify-center py-12 px-4 sm:px-6 lg:flex-none
    lg:px-20 xl:px-24
    """

    set :strategy_class, "mx-auto w-full max-w-sm lg:w-96"
  end

  override Components.Confirm.Input do
    set :submit_class, """
    w-full flex justify-center py-2 px-4 border border-transparent rounded-md
    shadow-sm text-sm font-medium text-white bg-blue-500 hover:bg-blue-600
    focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500
    mt-4 mb-4
    """
  end

  override ResetLive do
    set :root_class, "grid h-screen place-items-center dark:bg-gray-900"
  end

  override Components.Reset do
    set :root_class, """
    flex-1 flex flex-col justify-center py-12 px-4 sm:px-6 lg:flex-none
    lg:px-20 xl:px-24
    """

    set :strategy_class, "mx-auto w-full max-w-sm lg:w-96"
  end

  override Components.Reset.Form do
    set :root_class, nil
    set :label_class, "mt-2 mb-4 text-2xl tracking-tight font-bold text-gray-900 dark:text-white"
    set :form_class, nil
    set :spacer_class, "py-1"
    set :button_text, "Change password"
    set :disable_button_text, "Changing password ..."
  end

  override Components.SignIn do
    set :root_class, """
    flex-1 flex flex-col justify-center py-12 px-4 sm:px-6 lg:flex-none
    lg:px-20 xl:px-24
    """

    set :strategy_class, "mx-auto w-full max-w-sm lg:w-96"

    set :authentication_error_container_class, "text-black dark:text-white text-center"
    set :authentication_error_text_class, ""
    set :strategy_display_order, :forms_first
  end

  override Components.Banner do
    set :root_class, "w-full flex justify-center py-2"
    set :href_class, nil
    set :href_url, "/"
    set :image_class, "block dark:hidden"
    set :dark_image_class, "hidden dark:block"
    set :image_url, "https://ash-hq.org/images/ash-framework-light.png"
    set :dark_image_url, "https://ash-hq.org/images/ash-framework-dark.png"
    set :text_class, nil
    set :text, nil
  end

  override Components.HorizontalRule do
    set :root_class, "relative my-2"
    set :hr_outer_class, "absolute inset-0 flex items-center"
    set :hr_inner_class, "w-full border-t border-gray-300 dark:border-gray-700"
    set :text_outer_class, "relative flex justify-center text-sm"

    set :text_inner_class,
        "px-2 bg-white text-gray-400 font-medium dark:bg-gray-900 dark:text-gray-500"

    set :text, "or"
  end

  override MagicSignInLive do
    set :root_class, "grid h-screen place-items-center dark:bg-gray-900"
  end

  override Components.MagicLink do
    set :root_class, "mt-4 mb-4"
    set :label_class, "mt-2 mb-4 text-2xl tracking-tight font-bold text-gray-900 dark:text-white"
    set :form_class, nil

    set :request_flash_text,
        "If this user exists in our database, you will be contacted with a sign-in link shortly."

    set :disable_button_text, "Requesting ..."
  end

  override Components.MagicLink.Input do
    set :submit_class, """
    w-full flex justify-center py-2 px-4 border border-transparent rounded-md
    shadow-sm text-sm font-medium text-white bg-blue-500 hover:bg-blue-600
    focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500
    mt-4 mb-4
    """
  end

  override Components.Password do
    set :root_class, "mt-4 mb-4"
    set :interstitial_class, "flex flex-row justify-between content-between text-sm font-medium"
    set :toggler_class, "flex-none text-blue-500 hover:text-blue-600 px-2 first:pl-0 last:pr-0"
    set :sign_in_toggle_text, "Already have an account?"
    set :register_toggle_text, "Need an account?"
    set :reset_toggle_text, "Forgot your password?"
    set :show_first, :sign_in
    set :hide_class, "hidden"
    set :register_form_module, AshAuthentication.Phoenix.Components.Password.RegisterForm
  end

  override Components.Password.SignInForm do
    set :root_class, nil
    set :label_class, "mt-2 mb-4 text-2xl tracking-tight font-bold text-gray-900 dark:text-white"
    set :form_class, nil
    set :slot_class, "my-4"
    set :button_text, "Sign in"
    set :disable_button_text, "Signing in ..."
  end

  override Components.Password.RegisterForm do
    set :root_class, nil
    set :label_class, "mt-2 mb-4 text-2xl tracking-tight font-bold text-gray-900 dark:text-white"
    set :form_class, nil
    set :slot_class, "my-4"
    set :button_text, "Register"
    set :disable_button_text, "Registering ..."
  end

  override Components.Password.ResetForm do
    set :root_class, nil
    set :label_class, "mt-2 mb-4 text-2xl tracking-tight font-bold text-gray-900 dark:text-white"
    set :form_class, nil
    set :slot_class, "my-4"
    set :button_text, "Request reset password link"
    set :disable_button_text, "Requesting ..."

    set :reset_flash_text,
        "If this user exists in our system, you will be contacted with password reset instructions shortly."
  end

  override Components.Password.Input do
    set :field_class, "mt-2 mb-2 dark:text-white"
    set :label_class, "block text-sm font-medium text-gray-700 mb-1 dark:text-white"

    @base_input_class """
    appearance-none block w-full px-3 py-2 border rounded-md
    shadow-sm placeholder-gray-400 focus:outline-none sm:text-sm
    dark:text-black
    """

    set :input_class,
        @base_input_class <>
          """
          border-gray-300 focus:ring-blue-400 focus:border-blue-500
          """

    set :input_class_with_error,
        @base_input_class <>
          """
          border-red-400 focus:border-red-400 focus:ring-red-300
          """

    set :submit_class, """
    w-full flex justify-center py-2 px-4 border border-transparent rounded-md
    shadow-sm text-sm font-medium text-white bg-blue-500 hover:bg-blue-600
    focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500
    mt-4 mb-4
    """

    set :password_input_label, "Password"
    set :password_confirmation_input_label, "Password Confirmation"
    set :identity_input_label, "Email"
    set :identity_input_placeholder, nil
    set :error_ul, "text-red-400 font-light my-3 italic text-sm"
    set :error_li, nil
    set :input_debounce, 350
  end

  override Components.OAuth2 do
    set :root_class, "w-full mt-2 mb-4"

    set :link_class, """
    w-full flex justify-center py-2 px-4 border border-transparent rounded-md
    shadow-sm text-sm font-medium text-black bg-gray-200 hover:bg-gray-300
    focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500
    inline-flex items-center
    """

    set :icon_class, "-ml-0.4 mr-2 h-4 w-4"
  end

  override Components.Apple do
    set :root_class, "w-full mt-2 mb-4"

    set :link_class, """
    w-full flex justify-center px-4 border border-transparent rounded-md
    shadow-sm text-sm font-medium text-white bg-black focus:outline-none
    focus:ring-2 focus:ring-offset-2 focus:ring-black inline-flex items-center
    dark:bg-white dark:text-black dark:ring-white
    """

    set :icon_class, ""
  end
end
