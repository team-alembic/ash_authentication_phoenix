# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

# Used by "mix format"
locals_without_parens = [
  sign_in_route: 1,
  sign_out_route: 1,
  sign_out_route: 2,
  sign_out_route: 3,
  auth_routes_for: 2,
  confirm_route: 2,
  confirm_route: 3,
  auth_routes: 2,
  auth_routes: 3,
  reset_route: 1,
  totp_2fa_route: 2,
  totp_2fa_route: 3,
  totp_setup_route: 2,
  totp_setup_route: 3,
  webauthn_2fa_route: 2,
  webauthn_2fa_route: 3,
  webauthn_setup_route: 2,
  webauthn_setup_route: 3,
  recovery_code_verify_route: 2,
  recovery_code_verify_route: 3,
  recovery_code_display_route: 2,
  recovery_code_display_route: 3,
  magic_sign_in_route: 2,
  magic_sign_in_route: 3,
  set: 2,
  ash_authentication_live_session: 1,
  ash_authentication_live_session: 2
]

[
  import_deps: [:ash, :ash_authentication, :phoenix, :phoenix_live_view],
  inputs: ["{mix,.formatter}.exs", "{dev,config,lib,test}/**/*.{heex,ex,exs}"],
  locals_without_parens: locals_without_parens,
  export: [
    locals_without_parens: locals_without_parens
  ],
  plugins: [Phoenix.LiveView.HTMLFormatter]
]
