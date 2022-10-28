# Used by "mix format"
locals_without_parens = [
  sign_in_route: 0,
  sign_in_route: 1,
  sign_in_route: 2,
  sign_in_route: 3,
  sign_out_route: 1,
  sign_out_route: 2,
  sign_out_route: 3,
  auth_routes: 1,
  auth_routes: 2,
  auth_routes: 3,
  set: 2
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
