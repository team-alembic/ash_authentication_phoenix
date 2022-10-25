defmodule AshAuthentication.Phoenix do
  @moduledoc """
  Welcome to `AshAuthentication.Pheonix`.

  The `ash_authentication_phoenix` package extends
  [`ash_authentication`](https://github.com/team-alembic/ash_authentication) by
  adding router helpers, plugs and behaviours that makes adding authentication
  to an existing Ash-based Phoenix application dead easy.

  ## Where to start.

  Presuming that you already have [Phoenix](https://phoenixframework.org/),
  [Ash](https://ash-hq.org/) and
  [AshAuthentication](https://github.com/team-alembic/ash_authentication)
  installed and configured, start by adding plugs and routes to your router
  using `AshAuthentication.Phoenix.Router` and customising your sign-in page as
  needed.

  ### Customisation

  There are several methods of customisation available depending on the level of
  control you would like:

    1. Use the generic sign-in liveview -
       `AshAuthentication.Phoenix.SignInLive`.
    2. Apply overrides using `AshAuthentication.Phoenix.Overrides` to set your
       own CSS classes for all components.
    3. Build your own sign-in pages using the pre-defined components.
    4. Build your own sign-in pages using the generated `auth` routes.

  """
end
