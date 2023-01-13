# Used by "mix format"
locals_without_parens = [
  sign_in_route: 1,
  sign_in_route: 2,
  sign_in_route: 3,
  sign_out_route: 1,
  sign_out_route: 2,
  sign_out_route: 3,
  auth_routes_for: 1,
  auth_routes_for: 2,
  auth_routes_for: 3,
  reset_route: 1,
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
