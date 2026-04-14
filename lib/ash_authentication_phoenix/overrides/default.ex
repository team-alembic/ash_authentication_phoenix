# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

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
    RecoveryCodeDisplayLive,
    RecoveryCodeVerifyLive,
    ResetLive,
    SignInLive,
    SignOutLive,
    TotpSetupLive,
    TotpVerifyLive
  }

  override SignInLive do
    set :root_class, "grid h-screen place-items-center dark:bg-gray-900"
  end

  override SignOutLive do
    set :root_class, "grid h-screen place-items-center dark:bg-gray-900"
  end

  override Components.SignOut do
    set :root_class, """
    flex-1 flex flex-col justify-center py-12 px-4 sm:px-6 lg:flex-none
    lg:px-20 xl:px-24 mx-auto w-full max-w-sm lg:w-96
    """

    set :h2_class,
        "mt-2 mb-4 text-2xl tracking-tight font-bold text-gray-900 dark:text-white"

    set :h2_text, "Sign out"
    set :info_text, "Are you sure you want to sign out?"
    set :info_text_class, "text-sm text-gray-600 dark:text-gray-400 mb-4"
    set :form_class, nil

    set :button_text, "Sign out"

    set :button_class, """
    w-full flex justify-center py-2 px-4 border border-transparent rounded-md
    shadow-sm text-sm font-medium text-white bg-blue-500 hover:bg-blue-600
    focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500
    """
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

  override Components.Flash do
    set :message_class_info, """
    fixed top-2 right-2 mr-2 w-80 sm:w-96 z-50 rounded-lg p-3 text-sm
    bg-emerald-100 dark:bg-emerald-200 text-emerald-800
    """

    set :message_class_error, """
    fixed top-2 right-2 mr-2 w-80 sm:w-96 z-50 rounded-lg p-3 text-sm
    bg-rose-100 dark:bg-rose-200 text-rose-900
    """
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

    set :input_debounce, 350
    set :remember_me_class, "flex items-center gap-2 mt-2 mb-2 dark:text-white"
    set :remember_me_input_label, "Remember me"
    set :checkbox_class, "dark:text-white mr-2"
    set :checkbox_label_class, "text-sm font-medium text-gray-700 dark:text-white"
    set :submit_label, "Sign in"
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
    set :sign_in_form_module, AshAuthentication.Phoenix.Components.Password.SignInForm
    set :reset_form_module, AshAuthentication.Phoenix.Components.Password.ResetForm
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
    bg-white dark:bg-gray-800 dark:text-white dark:placeholder-gray-500
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
    set :remember_me_class, "flex items-center gap-2 mt-2 mb-2 dark:text-white"
    set :remember_me_input_label, "Remember me"
    set :checkbox_class, "dark:text-white mr-2"
    set :checkbox_label_class, "text-sm font-medium text-gray-700 dark:text-white"
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

    set :icon_src, nil
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

  override Components.Totp do
    set :root_class, "mt-4 mb-4"
    set :hide_class, "hidden"
    set :show_first, :sign_in
    set :interstitial_class, "flex flex-row justify-between content-between text-sm font-medium"

    # Setup toggle disabled by default - TOTP setup should be on a dedicated page for authenticated users
    set :sign_in_toggle_text, nil
    set :setup_toggle_text, nil
    set :toggler_class, "flex-none text-blue-500 hover:text-blue-600 px-2 first:pl-0 last:pr-0"
    set :sign_in_form_module, AshAuthentication.Phoenix.Components.Totp.SignInForm
    set :setup_form_module, AshAuthentication.Phoenix.Components.Totp.SetupForm
    set :slot_class, "my-4"
  end

  override Components.Totp.SignInForm do
    set :root_class, nil
    set :label_class, "mt-2 mb-4 text-2xl tracking-tight font-bold text-gray-900 dark:text-white"
    set :form_class, nil
    set :slot_class, "my-4"
    set :button_text, "Sign in"
    set :disable_button_text, "Signing in ..."
  end

  override Components.Totp.SetupForm do
    set :root_class, nil
    set :label_class, "mt-2 mb-4 text-2xl tracking-tight font-bold text-gray-900 dark:text-white"
    set :instructions_class, "text-sm text-gray-600 dark:text-gray-400 mb-4"

    set :instructions_text,
        "Scan this QR code with your authenticator app, then enter the code below."

    set :qr_code_class, "flex justify-center mb-4"
    set :qr_code_wrapper_class, "text-center"
    set :form_class, nil
    set :slot_class, "my-4"
    set :button_text, "Confirm setup"
    set :disable_button_text, "Confirming ..."
    set :setup_button_text, "Set up authenticator"

    set :setup_button_class, """
    w-full flex justify-center py-2 px-4 border border-transparent rounded-md
    shadow-sm text-sm font-medium text-white bg-blue-500 hover:bg-blue-600
    focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500
    """

    set :error_class, "text-red-500 text-sm mb-4"
  end

  override Components.Totp.Input do
    set :field_class, "mt-2 mb-2 dark:text-white"
    set :label_class, "block text-sm font-medium text-gray-700 mb-1 dark:text-white"

    @totp_base_input_class """
    appearance-none block w-full px-3 py-2 border rounded-md
    shadow-sm placeholder-gray-400 focus:outline-none sm:text-sm
    dark:text-white
    """

    set :input_class,
        @totp_base_input_class <>
          """
          border-gray-300 focus:ring-blue-400 focus:border-blue-500
          """

    set :input_class_with_error,
        @totp_base_input_class <>
          """
          border-red-400 focus:border-red-400 focus:ring-red-300
          """

    set :valid_code_class,
        @totp_base_input_class <>
          """
          border-green-400 focus:border-green-400 focus:ring-green-300
          """

    set :invalid_code_class,
        @totp_base_input_class <>
          """
          border-red-400 focus:border-red-400 focus:ring-red-300
          """

    set :submit_class, """
    w-full flex justify-center py-2 px-4 border border-transparent rounded-md
    shadow-sm text-sm font-medium text-white bg-blue-500 hover:bg-blue-600
    focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500
    mt-4 mb-4
    """

    set :identity_input_label, "Email"
    set :identity_input_placeholder, nil
    set :code_input_label, "Authentication Code"
    set :code_input_placeholder, "000000"
    set :error_ul, "text-red-400 font-light my-3 italic text-sm"
    set :error_li, nil
    set :input_debounce, 350
  end

  override TotpVerifyLive do
    set :root_class, "grid h-screen place-items-center dark:bg-gray-900"
  end

  override TotpSetupLive do
    set :root_class, "grid h-screen place-items-center dark:bg-gray-900"
    set :error_class, "text-red-500 text-center"
  end

  override Components.Totp.Verify2faForm do
    set :root_class, """
    flex-1 flex flex-col justify-center py-12 px-4 sm:px-6 lg:flex-none
    lg:px-20 xl:px-24 mx-auto w-full max-w-sm lg:w-96
    """

    set :label_class, "mt-2 mb-4 text-2xl tracking-tight font-bold text-gray-900 dark:text-white"
    set :label_text, "Two-Factor Authentication"
    set :instructions_class, "text-sm text-gray-600 dark:text-gray-400 mb-4"
    set :instructions_text, "Enter the 6-digit code from your authenticator app."
    set :form_class, nil
    set :slot_class, "my-4"
    set :button_text, "Verify"
    set :disable_button_text, "Verifying ..."
    set :error_class, "text-red-500 text-sm mb-4"
    set :sign_in_link_class, "text-blue-500 hover:text-blue-600"
    set :sign_in_link_text, "Sign in"
    set :recovery_code_link_class, "text-blue-500 hover:text-blue-600 text-sm mt-4 block"
    set :recovery_code_link_text, "Use a recovery code instead"
    set :recovery_code_link_path, nil
  end

  override RecoveryCodeVerifyLive do
    set :root_class, "grid h-screen place-items-center dark:bg-gray-900"
  end

  override RecoveryCodeDisplayLive do
    set :root_class, "grid h-screen place-items-center dark:bg-gray-900"
    set :error_class, "text-red-500 text-center"
  end

  override Components.RecoveryCode.VerifyForm do
    set :root_class, """
    flex-1 flex flex-col justify-center py-12 px-4 sm:px-6 lg:flex-none
    lg:px-20 xl:px-24 mx-auto w-full max-w-sm lg:w-96
    """

    set :label_class, "mt-2 mb-4 text-2xl tracking-tight font-bold text-gray-900 dark:text-white"
    set :label_text, "Recovery Code"
    set :instructions_class, "text-sm text-gray-600 dark:text-gray-400 mb-4"
    set :instructions_text, "Enter one of your recovery codes."
    set :form_class, nil
    set :slot_class, "my-4"
    set :button_text, "Verify"
    set :disable_button_text, "Verifying ..."
    set :error_class, "text-red-500 text-sm mb-4"
    set :sign_in_link_class, "text-blue-500 hover:text-blue-600"
    set :sign_in_link_text, "Sign in"
    set :totp_link_class, "text-blue-500 hover:text-blue-600 text-sm mt-4 block"
    set :totp_link_text, "Use authenticator app instead"
    set :totp_link_path, nil
  end

  override Components.RecoveryCode.DisplayCodes do
    set :root_class, """
    flex-1 flex flex-col justify-center py-12 px-4 sm:px-6 lg:flex-none
    lg:px-20 xl:px-24 mx-auto w-full max-w-sm lg:w-96
    """

    set :label_class, "mt-2 mb-4 text-2xl tracking-tight font-bold text-gray-900 dark:text-white"
    set :label_text, "Recovery Codes"
    set :instructions_class, "text-sm text-gray-600 dark:text-gray-400 mb-4"

    set :instructions_text,
        "Save these codes in a safe place. Each code can only be used once."

    set :codes_grid_class, "grid grid-cols-2 gap-2 my-4 font-mono text-sm"
    set :code_item_class, "p-2 bg-gray-100 dark:bg-gray-800 rounded text-center"
    set :warning_class, "text-amber-600 dark:text-amber-400 text-sm my-4"

    set :warning_text,
        "If you lose access to your authenticator app, you can use these codes to sign in."

    set :generate_button_class,
        "w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700"

    set :confirm_button_class,
        "w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-green-600 hover:bg-green-700"

    set :confirm_path, "/"
    set :error_class, "text-red-500 text-sm mb-4"
  end

  override Components.RecoveryCode.Input do
    set :field_class, "mt-2"
    set :label_class, "block text-sm font-medium text-gray-700 dark:text-gray-300"

    set :input_class, """
    mt-1 block w-full px-3 py-2 bg-white dark:bg-gray-800 border border-gray-300
    dark:border-gray-600 rounded-md shadow-sm placeholder-gray-400
    focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm
    font-mono tracking-widest uppercase
    """

    set :code_input_label, "Recovery Code"
    set :code_input_placeholder, "Enter recovery code"

    set :input_class_with_error, """
    mt-1 block w-full px-3 py-2 bg-white dark:bg-gray-800 border border-red-500
    rounded-md shadow-sm placeholder-gray-400
    focus:outline-none focus:ring-red-500 focus:border-red-500 sm:text-sm
    font-mono tracking-widest uppercase
    """

    set :submit_class,
        "w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 mt-4"

    set :error_ul, "mt-1"
    set :error_li, "text-red-500 text-xs"
    set :input_debounce, 350
  end

  override Components.WebAuthn do
    set :root_class, "mt-4 mb-4"
    set :hide_class, "hidden"
    set :show_first, :sign_in
    set :sign_in_toggle_text, "Already have a passkey? Sign in"
    set :register_toggle_text, "New here? Register a passkey"
    set :toggler_class, "text-sm text-blue-600 hover:text-blue-800 cursor-pointer"
    set :interstitial_class, "mt-4 text-center"
    set :slot_class, "mt-4"
  end

  override Components.WebAuthn.RegistrationForm do
    set :root_class, "mt-2"
    set :form_class, "space-y-4"
    set :button_text, "Register with Passkey"
    set :disable_button_text, "Registering..."
    set :slot_class, "mt-2"
  end

  override Components.WebAuthn.AuthenticationForm do
    set :root_class, "mt-2"
    set :form_class, "space-y-4"
    set :button_text, "Sign in with Passkey"
    set :disable_button_text, "Signing in..."
    set :slot_class, "mt-2"
    set :show_identity_field, false
  end

  override Components.WebAuthn.Input do
    set :identity_input_label, "Email"
    set :identity_input_placeholder, "you@example.com"
    set :field_class, "mb-4"
    set :label_class, "block text-sm font-medium text-gray-700 mb-1"

    set :input_class,
        "w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"

    set :input_class_with_error,
        "w-full px-3 py-2 border border-red-300 rounded-md shadow-sm focus:ring-red-500 focus:border-red-500"

    set :submit_class, """
    w-full flex justify-center items-center py-2 px-4 border border-transparent
    rounded-md shadow-sm text-sm font-medium text-white bg-blue-600
    hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2
    focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed
    """

    set :error_ul, "mt-1 text-sm text-red-600"
    set :error_li, ""
    set :register_button_text, "Register with Passkey"
    set :register_button_icon, nil
    set :sign_in_button_text, "Sign in with Passkey"
    set :sign_in_button_icon, nil
    set :disable_button_text, "Please wait..."
  end

  override Components.WebAuthn.Support do
    set :root_class, ""
    set :unsupported_message, "Your browser does not support passkeys."
  end

  override Components.WebAuthn.ManageCredentials do
    set :root_class, "max-w-lg mx-auto"
    set :heading_text, "Your Security Keys"
    set :heading_class, "text-xl font-semibold mb-4"
    set :credential_list_class, "divide-y divide-gray-200"
    set :credential_item_class, "py-4 flex justify-between items-center"
    set :add_button_text, "+ Add another security key"

    set :add_button_class, """
    mt-4 w-full flex justify-center py-2 px-4 border-2 border-dashed
    border-gray-300 rounded-md text-sm text-gray-600 hover:border-gray-400
    hover:text-gray-700
    """

    set :delete_button_text, "Delete"
    set :delete_button_class, "text-sm text-red-600 hover:text-red-800 ml-2"
    set :rename_button_text, "Rename"
    set :rename_button_class, "text-sm text-blue-600 hover:text-blue-800"
    set :save_button_text, "Save"
    set :cancel_button_text, "Cancel"
    set :empty_state_text, "No security keys registered."

    set :last_credential_warning,
        "Cannot delete your last security key. You would be locked out."

    set :label_input_class, "px-2 py-1 border border-gray-300 rounded text-sm"
    set :timestamp_class, "text-sm text-gray-500 ml-2"
  end
end
