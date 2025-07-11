# Overriding Ash Authentication Phoenix's default UI

Ash Authentication Phoenix provides a default UI implementation to get you started, however we wanted there to be a middle road between "you gets what you gets" and "¯\\_(ツ)_/¯ make your own". Thus AAP's system of UI overrides were born.

Each of our LiveView components has a number of hooks where you can override either the CSS styles, text or images.

In addition you have the option to provide a `gettext/2` compatible function through which all output text will be run.

## Defining Overrides

You override these components by defining an "overrides module", which you will then provide in your router when setting up your routes.

For example, if we wanted to change the default banner used on the sign-in page:

```elixir
defmodule MyAppWeb.AuthOverrides do
  use AshAuthentication.Phoenix.Overrides

  # Override a property per component
  override AshAuthentication.Phoenix.Components.Banner do
    # include any number of properties you want to override
    set :image_url, "/images/rickroll.gif"
    set :dark_image_url, "/images/rickroll-dark.gif"
  end
end
```

You only need to define the overrides you want to change. Unspecified overrides will use their default value.

When overriding UI elements, remember to account for dark mode support. Some properties have dark mode variants (prefixed with `dark_`) that should be set alongside their light mode counterparts. For instance, if you override `image_url`, you should typically also set `dark_image_url` to ensure your UI looks good in both light and dark modes.

## Internationalisation

Plug in your Gettext backend and have all display text translated automagically, see next section for an example.

The package includes Gettext templates for the untranslated messages and a growing number of translations. You might want to

```sh
cp -rv deps/ash_authentication_phoenix/i18n/gettext/* priv/gettext
```

For other i18n libraries you have the option to provide a gettext-like handler function, see `AshAuthentication.Phoenix.Router.sign_in_route/1` for details.

## Telling AshAuthentication about your overrides

To do this, you modify your `sign_in_route` calls to contain the `overrides` option. Be sure to put the
`AshAuthentication.Phoenix.Overrides.Default` override last, as it contains the default values for all components!

The same way you may add a `gettext_backend` option to specify your Gettext backend and domain.

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use AshAuthentication.Phoenix.Router

  # ...

  scope "/", MyAppWeb do
    sign_in_route overrides: [MyAppWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default],
                  gettext_backend: {MyAppWeb.Gettext, "auth"}
  end
end
```

## Reference

The below documentation is autogenerated from the components that support overrides.
All available overrides are listed here. If you are looking to override something not in this
list, please open an issue, or even better a PR!

Looking at the source of the components can be enlightening to see exactly how an override is used.
If you click on the name of component you are interested in, and then look in the top right (if you are on hexdocs),
you will see a `</>` button that will take you to the source for that component. In that code, look for
calls to `override_for/3` to see specifically how each override is used.

<!-- override-docs-begin -->

## Sign In
### `AshAuthentication.Phoenix.SignInLive`

A generic, white-label sign-in page.

  * `:root_class` - CSS class for the root `div` element.

  * `:sign_in_id` - Element ID for the `SignIn` LiveComponent.


### `AshAuthentication.Phoenix.Components.SignIn`

Renders sign in mark-up for an authenticated resource.

  * `:authentication_error_container_class` - CSS class for the container for the text of the authentication error.

  * `:authentication_error_text_class` - CSS class for the authentication error text.

  * `:root_class` - CSS class for the root `div` element.

  * `:show_banner` - Whether or not to show the banner.

  * `:strategy_class` - CSS class for a `div` surrounding each strategy component.

  * `:strategy_display_order` - Whether to display the form or link strategies first. Accepted values are `:forms_first` or `:links_first`.


## Password Sign-in
### `AshAuthentication.Phoenix.Components.Password`

Generates sign in, registration and reset forms for a resource.

  * `:hide_class` - CSS class to apply to hide an element.

  * `:interstitial_class` - CSS class for the `div` element between the form and the button.

  * `:register_form_module` - The Phoenix component to be used for the registration form. Defaults to `AshAuthentication.Phoenix.Components.Password.RegisterForm`.

  * `:register_toggle_text` - Toggle text to display when the register form is not showing (or `nil` to disable).

  * `:reset_form_module` - The Phoenix component to be used for the reset form. Defaults to `AshAuthentication.Phoenix.Components.Password.ResetForm`.

  * `:reset_toggle_text` - Toggle text to display when the reset form is not showing (or `nil` to disable).

  * `:root_class` - CSS class for the root `div` element.

  * `:show_first` - The form to show on first load.  Either `:sign_in` or `:register`. Only relevant if paths aren't set for them in the router.

  * `:sign_in_form_module` - The Phoenix component to be used for the sign in form. Defaults to `AshAuthentication.Phoenix.Components.Password.SignInForm`.

  * `:sign_in_toggle_text` - Toggle text to display when the sign in form is not showing (or `nil` to disable).

  * `:slot_class` - CSS class for the `div` surrounding the slot.

  * `:toggler_class` - CSS class for the toggler `a` element.


### `AshAuthentication.Phoenix.Components.Password.RegisterForm`

Generates a default registration form.

  * `:button_text` - Text for the submit button.

  * `:disable_button_text` - Text for the submit button when the request is happening.

  * `:form_class` - CSS class for the `form` element.

  * `:label_class` - CSS class for the `h2` element.

  * `:root_class` - CSS class for the root `div` element.

  * `:slot_class` - CSS class for the `div` surrounding the slot.


### `AshAuthentication.Phoenix.Components.Password.SignInForm`

Generates a default sign in form.

  * `:button_text` - Text for the submit button.

  * `:disable_button_text` - Text for the submit button when the request is happening.

  * `:form_class` - CSS class for the `form` element.

  * `:label_class` - CSS class for the `h2` element.

  * `:root_class` - CSS class for the root `div` element.

  * `:slot_class` - CSS class for the `div` surrounding the slot.


## Confirmation
### `AshAuthentication.Phoenix.ConfirmLive`

A generic, white-label confirmation page.

  * `:confirm_id` - Element ID for the `Reset` LiveComponent.

  * `:root_class` - CSS class for the root `div` element.


### `AshAuthentication.Phoenix.Components.Confirm`

Renders a confirmation button.

  * `:root_class` - CSS class for the root `div` element.

  * `:show_banner` - Whether or not to show the banner.

  * `:strategy_class` - CSS class for a `div` surrounding each strategy component.


### `AshAuthentication.Phoenix.Components.Confirm.Form`

Generates a default confirmation form.

  * `:disable_button_text` - Text for the submit button when the request is happening.

  * `:form_class` - CSS class for the `form` element.

  * `:label_class` - CSS class for the `h2` element.

  * `:root_class` - CSS class for the root `div` element.


### `AshAuthentication.Phoenix.Components.Confirm.Input`

Function components for dealing with form input during password
authentication.

  * `:submit_class` - CSS class for the form submit `input` element.

  * `:submit_label` - A function that takes the strategy and returns text for the confirm button, or a string.


## Password Reset
### `AshAuthentication.Phoenix.ResetLive`

A generic, white-label password reset page.

  * `:reset_id` - Element ID for the `Reset` LiveComponent.

  * `:root_class` - CSS class for the root `div` element.


### `AshAuthentication.Phoenix.Components.Reset`

Renders a password-reset form.

  * `:root_class` - CSS class for the root `div` element.

  * `:show_banner` - Whether or not to show the banner.

  * `:strategy_class` - CSS class for a `div` surrounding each strategy component.


### `AshAuthentication.Phoenix.Components.Reset.Form`

Generates a default password reset form.

  * `:disable_button_text` - Text for the submit button when the request is happening.

  * `:form_class` - CSS class for the `form` element.

  * `:label_class` - CSS class for the `h2` element.

  * `:root_class` - CSS class for the root `div` element.

  * `:spacer_class` - CSS classes for space between the password input and submit elements.


### `AshAuthentication.Phoenix.Components.Password.ResetForm`

Generates a default password reset form.

  * `:button_text` - Tex for the submit button.

  * `:disable_button_text` - Text for the submit button when the request is happening.

  * `:form_class` - CSS class for the `form` element.

  * `:label_class` - CSS class for the `h2` element.

  * `:reset_flash_text` - Text for the flash message when a request is received.  Set to `nil` to disable.

  * `:root_class` - CSS class for the root `div` element.

  * `:slot_class` - CSS class for the `div` surrounding the slot.


## Password
### `AshAuthentication.Phoenix.Components.Password.Input`

Function components for dealing with form input during password
authentication.

  * `:error_li` - CSS class for the `li` elements on error lists.

  * `:error_ul` - CSS class for the `ul` element on error lists.

  * `:field_class` - CSS class for `div` elements surrounding the fields.

  * `:identity_input_label` - Label for identity field.

  * `:identity_input_placeholder` - Placeholder for identity field.

  * `:input_class` - CSS class for text/password `input` elements.

  * `:input_class_with_error` - CSS class for text/password `input` elements when there is a validation error.

  * `:input_debounce` - Number of milliseconds to debounce input by (or `nil` to disable).

  * `:label_class` - CSS class for `label` elements.

  * `:password_confirmation_input_label` - Label for password confirmation field.

  * `:password_input_label` - Label for password field.

  * `:submit_class` - CSS class for the form submit `input` element.


## Magic Link
### `AshAuthentication.Phoenix.MagicSignInLive`

A generic, white-label confirmation page.

  * `:magic_sign_in_id` - Element ID for the `MagicSignIn` LiveComponent.

  * `:root_class` - CSS class for the root `div` element.


### `AshAuthentication.Phoenix.Components.MagicLink`

Generates a sign-in for for a resource using the "Magic link" strategy.

  * `:disable_button_text` - Text for the submit button when the request is happening.

  * `:form_class` - CSS class for the `form` element.

  * `:label_class` - CSS class for the `h2` element.

  * `:request_flash_text` - Text for the flash message when a request is received.  Set to `nil` to disable.

  * `:root_class` - CSS class for the root `div` element.


### `AshAuthentication.Phoenix.Components.MagicLink.SignIn`

Renders a magic sign in button.

  * `:root_class` - CSS class for the root `div` element.

  * `:show_banner` - Whether or not to show the banner

  * `:strategy_class` - CSS class for the `div` surrounding each strategy component.


### `AshAuthentication.Phoenix.Components.MagicLink.Form`

Generates a default magic sign in form.

  * `:disable_button_text` - Text for the submit button when the request is happening.

  * `:form_class` - CSS class for the `form` element.

  * `:label_class` - CSS class for the `h2` element.

  * `:root_class` - CSS class for root `div` element.


### `AshAuthentication.Phoenix.Components.MagicLink.Input`

Function components for dealing with form input during magic link sign in.

  * `:submit_class` - CSS class for the form submit `input` element.

  * `:submit_label` - A function that takes the strategy and returns text for the sign in button, or a string.


## OAuth2
### `AshAuthentication.Phoenix.Components.Apple`

Generates a sign-in button for Apple.

  * `:icon_class` - CSS classes for the icon SVG.

  * `:link_class` - CSS classes for the `a` element.

  * `:root_class` - CSS classes for the root `div` element.


### `AshAuthentication.Phoenix.Components.OAuth2`

Generates a sign-in button for OAuth2.

  * `:icon_class` - CSS classes for the icon SVG.

  * `:link_class` - CSS classes for the `a` element.

  * `:root_class` - CSS classes for the root `div` element.


## Miscellaneous
### `AshAuthentication.Phoenix.Components.HorizontalRule`

A horizontal rule with text.

  * `:hr_inner_class` - CSS class for the inner `div` element of the horizontal rule.

  * `:hr_outer_class` - CSS class for the outer `div` element of the horizontal rule.

  * `:root_class` - CSS class for the root `div` element.

  * `:text` - Text to display in front of the horizontal rule.

  * `:text_inner_class` - CSS class for the inner `div` element of the text area.

  * `:text_outer_class` - CSS class for the outer `div` element of the text area.


### `AshAuthentication.Phoenix.Components.Banner`

Renders a very simple banner at the top of the sign-in component.

  * `:dark_image_class` - Css class for the `img` tag in dark mode.

  * `:dark_image_url` - A URL for the `img` `src` attribute in dark mode. Set to `nil` to disable.

  * `:href_class` - CSS class for the `a` tag.

  * `:href_url` - A URL for the banner image to link to. Set to `nil` to disable.

  * `:image_class` - CSS class for the `img` tag.

  * `:image_url` - A URL for the `img` `src` attribute. Set to `nil` to disable.

  * `:root_class` - CSS class for the root `div` element.

  * `:text` - Banner text. Set to `nil` to disable.

  * `:text_class` - CSS class for the text `div`.



<!-- override-docs-end -->
