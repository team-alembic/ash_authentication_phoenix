# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Overrides.DaisyUI do
  @moduledoc """
  This is the daisyUI overrides for our component UI.
  Copied from the AshAuthentication.Phoenix.Overrides.Default module with tweaks.

  The CSS styles are based on [daisyUI](https://daisyui.com/).
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
    set :root_class, "grid h-screen place-items-center bg-base-100"
  end

  override ConfirmLive do
    set :root_class, "grid h-screen place-items-center bg-base-100"
  end

  override Components.Confirm do
    set :root_class, """
    flex-1 flex flex-col justify-center py-12 px-4 sm:px-6 lg:flex-none
    lg:px-20 xl:px-24
    """

    set :strategy_class, "mx-auto w-full max-w-sm lg:w-96"
  end

  override Components.Confirm.Input do
    set :submit_class, "btn btn-primary btn-block mt-4 mb-4"
  end

  override ResetLive do
    set :root_class, "grid h-screen place-items-center bg-base-100"
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
    set :label_class, "mt-2 mb-4 text-2xl tracking-tight font-bold text-base-content"
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

    set :authentication_error_container_class, "text-base-content text-center"
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
    set :root_class, "divider my-2"
    set :hr_outer_class, "hidden"
    set :hr_inner_class, "hidden"
    set :text_outer_class, "contents"
    set :text_inner_class, "contents"
    set :text, "or"
  end

  override MagicSignInLive do
    set :root_class, "grid h-screen place-items-center bg-base-100"
  end

  override Components.MagicLink do
    set :root_class, "mt-4 mb-4"
    set :label_class, "mt-2 mb-4 text-2xl tracking-tight font-bold text-base-content"
    set :form_class, nil

    set :request_flash_text,
        "If this user exists in our database, you will be contacted with a sign-in link shortly."

    set :disable_button_text, "Requesting ..."
  end

  override Components.MagicLink.Input do
    set :submit_class, "btn btn-primary btn-block mt-4 mb-4"
    set :submit_label, "Sign in"
  end

  override Components.Password do
    set :root_class, "mt-4 mb-4"
    set :interstitial_class, "flex flex-row justify-between content-between text-sm font-medium"

    set :toggler_class,
        "flex-none text-primary hover:text-primary-focus px-2 first:pl-0 last:pr-0"

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
    set :label_class, "mt-2 mb-4 text-2xl tracking-tight font-bold text-base-content"
    set :form_class, nil
    set :slot_class, "my-4"
    set :button_text, "Sign in"
    set :disable_button_text, "Signing in ..."
  end

  override Components.Password.RegisterForm do
    set :root_class, nil
    set :label_class, "mt-2 mb-4 text-2xl tracking-tight font-bold text-base-content"
    set :form_class, nil
    set :slot_class, "my-4"
    set :button_text, "Register"
    set :disable_button_text, "Registering ..."
  end

  override Components.Password.ResetForm do
    set :root_class, nil
    set :label_class, "mt-2 mb-4 text-2xl tracking-tight font-bold text-base-content"
    set :form_class, nil
    set :slot_class, "my-4"
    set :button_text, "Request reset password link"
    set :disable_button_text, "Requesting ..."

    set :reset_flash_text,
        "If this user exists in our system, you will be contacted with password reset instructions shortly."
  end

  override Components.Password.Input do
    set :field_class, "mt-2 mb-2"
    set :label_class, "block text-sm font-medium text-base-content mb-1"

    @base_input_class "input w-full"

    set :input_class, @base_input_class

    set :input_class_with_error, @base_input_class <> " input-error"

    set :submit_class, "btn btn-primary btn-block mt-4 mb-4"

    set :password_input_label, "Password"
    set :password_confirmation_input_label, "Password Confirmation"
    set :identity_input_label, "Email"
    set :identity_input_placeholder, nil
    set :error_ul, "text-error font-light my-3 italic text-sm"
    set :error_li, nil
    set :input_debounce, 350

    set :remember_me_class, "flex items-center gap-2 mt-2 mb-2 dark:text-white"
    set :remember_me_input_label, "Remember me"
    set :checkbox_class, "dark:text-white mr-2"
    set :checkbox_label_class, "text-sm font-medium text-gray-700 dark:text-white"
  end

  override Components.OAuth2 do
    set :root_class, "w-full mt-2 mb-4"

    set :link_class, "btn btn-outline btn-block"

    set :icon_class, "-ml-0.4 mr-2 h-4 w-4"

    set :icon_src, nil
  end

  override Components.Apple do
    set :root_class, "w-full mt-2 mb-4"

    set :link_class, "btn btn-neutral btn-block"

    set :icon_class, ""
  end
end
