# Used by "mix format"
[
  import_deps: [:ash, :ash_authentication, :phoenix],
  inputs: ["{mix,.formatter}.exs", "{dev,config,lib,test}/**/*.{ex,exs}"],
  export: [
    locals_without_parens: [
      sign_in_route: 0,
      sign_in_route: 1,
      sign_in_route: 2,
      sign_in_route: 3,
      sign_out_route: 1,
      sign_out_route: 2,
      sign_out_route: 3,
      auth_routes: 1,
      auth_routes: 2,
      auth_routes: 3
    ]
  ]
]
