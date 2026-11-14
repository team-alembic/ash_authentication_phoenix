# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

# credo:disable-for-this-file Credo.Check.Design.AliasUsage
defmodule Mix.Tasks.AshAuthenticationPhoenix.AddStrategy.WebauthnTest do
  use ExUnit.Case

  import Igniter.Test

  @moduletag :igniter
  @moduletag feature: :webauthn

  @vanilla_app_js """
  import "phoenix_html"
  import { Socket } from "phoenix"
  import { LiveSocket } from "phoenix_live_view"

  let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
  let liveSocket = new LiveSocket("/live", Socket, {
    longPollFallbackMs: 2500,
    params: { _csrf_token: csrfToken }
  })

  liveSocket.connect()
  """

  defp project_with_app_js(app_js \\ @vanilla_app_js) do
    test_project(files: %{"assets/js/app.js" => app_js})
  end

  @import_line ~S|import { WebAuthnRegistrationHook, WebAuthnAuthenticationHook, WebAuthnSupportHook } from "ash_authentication_phoenix/priv/static/webauthn_hooks.js"|

  defp wired_app_js(app_js) do
    project_with_app_js(app_js)
    |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.webauthn", [])
    |> apply_igniter!()
    |> Map.fetch!(:rewrite)
    |> Rewrite.source!("assets/js/app.js")
    |> Rewrite.Source.get(:content)
  end

  describe "with a vanilla app.js" do
    test "imports the webauthn hooks module after the last import, in the file's style" do
      project_with_app_js()
      |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.webauthn", [])
      |> assert_has_patch("assets/js/app.js", """
        |import { LiveSocket } from "phoenix_live_view"
      + |#{@import_line}
      """)
    end

    test "registers the hooks on the LiveSocket, one per line like the other options" do
      project_with_app_js()
      |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.webauthn", [])
      |> assert_has_patch("assets/js/app.js", """
        |  longPollFallbackMs: 2500,
      - |  params: { _csrf_token: csrfToken }
      + |  params: { _csrf_token: csrfToken },
      + |  hooks: {
      + |    WebAuthnRegistrationHook,
      + |    WebAuthnAuthenticationHook,
      + |    WebAuthnSupportHook
      + |  }
        |})
      """)
    end

    test "is idempotent" do
      igniter =
        project_with_app_js()
        |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.webauthn", [])
        |> apply_igniter!()

      igniter
      |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.webauthn", [])
      |> assert_unchanged("assets/js/app.js")
    end
  end

  # A stock Phoenix 1.8 `app.js`: colocated hooks spread into `hooks`,
  # trailing commas, no spaces inside braces, comments, and no semicolons.
  # The codemod must add its lines and change nothing else.
  describe "with a Phoenix 1.8 app.js" do
    @phoenix_1_8_head """
    // If you want to use Phoenix channels, run `mix help phx.gen.channel`
    // to get started and then uncomment the line below.
    // import "./user_socket.js"

    // Include phoenix_html to handle method=PUT/DELETE in forms and buttons — 🔐 ünïcode too.
    import "phoenix_html"
    // Establish Phoenix Socket and LiveView configuration.
    import {Socket} from "phoenix"
    import {LiveSocket} from "phoenix_live_view"
    import {hooks as colocatedHooks} from "phoenix-colocated/my_app"
    import topbar from "../vendor/topbar"
    """

    @phoenix_1_8_tail """

    const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
    const liveSocket = new LiveSocket("/live", Socket, {
      longPollFallbackMs: 2500,
      params: {_csrf_token: csrfToken},
      hooks: {...colocatedHooks},
    })

    // Show progress bar on live navigation and form submits
    topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
    window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
    window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

    // connect if there are any LiveViews on the page
    liveSocket.connect()

    if (process.env.NODE_ENV === "development") {
      window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
        let keyDown
        window.addEventListener("keydown", e => keyDown = e.key)
        window.addEventListener("click", e => {
          if(keyDown === "c"){
            e.preventDefault()
            reloader.openEditorAtCaller(e.target)
          }
        }, true)
      })
    }
    """

    test "adds only the import and the three hook names" do
      wired = wired_app_js(@phoenix_1_8_head <> @phoenix_1_8_tail)

      expected =
        @phoenix_1_8_head <>
          @import_line <>
          "\n" <>
          String.replace(
            @phoenix_1_8_tail,
            "  hooks: {...colocatedHooks},",
            "  hooks: {...colocatedHooks, WebAuthnRegistrationHook, WebAuthnAuthenticationHook, WebAuthnSupportHook},"
          )

      assert wired == expected
    end

    test "fills a multi-line hooks object one hook per line, keeping its trailing comma" do
      multiline_hooks = """
      import {Socket} from "phoenix"
      import {hooks as colocatedHooks} from "phoenix-colocated/my_app"

      const liveSocket = new LiveSocket("/live", Socket, {
        params: {_csrf_token: csrfToken},
        hooks: {
          ...colocatedHooks,
        },
      })
      """

      assert wired_app_js(multiline_hooks) == """
             import {Socket} from "phoenix"
             import {hooks as colocatedHooks} from "phoenix-colocated/my_app"
             #{@import_line}

             const liveSocket = new LiveSocket("/live", Socket, {
               params: {_csrf_token: csrfToken},
               hooks: {
                 ...colocatedHooks,
                 WebAuthnRegistrationHook,
                 WebAuthnAuthenticationHook,
                 WebAuthnSupportHook,
               },
             })
             """
    end

    test "adds a hooks object with trailing commas when the options have them" do
      no_hooks = """
      import {Socket} from "phoenix"

      const liveSocket = new LiveSocket("/live", Socket, {
        longPollFallbackMs: 2500,
        params: {_csrf_token: csrfToken},
      })
      """

      assert wired_app_js(no_hooks) == """
             import {Socket} from "phoenix"
             #{@import_line}

             const liveSocket = new LiveSocket("/live", Socket, {
               longPollFallbackMs: 2500,
               params: {_csrf_token: csrfToken},
               hooks: {
                 WebAuthnRegistrationHook,
                 WebAuthnAuthenticationHook,
                 WebAuthnSupportHook,
               },
             })
             """
    end

    test "ends its import with a semicolon when the other imports have one" do
      semicolons = """
      import {Socket} from "phoenix";
      import {LiveSocket} from "phoenix_live_view";

      let liveSocket = new LiveSocket("/live", Socket, {params: {}});
      """

      assert wired_app_js(semicolons) == """
             import {Socket} from "phoenix";
             import {LiveSocket} from "phoenix_live_view";
             #{@import_line};

             let liveSocket = new LiveSocket("/live", Socket, {params: {}, hooks: { WebAuthnRegistrationHook, WebAuthnAuthenticationHook, WebAuthnSupportHook }});
             """
    end
  end

  describe "with an existing hooks key" do
    test "appends our hooks alongside existing ones" do
      app_js = """
      import "phoenix_html"
      import { Socket } from "phoenix"
      import { LiveSocket } from "phoenix_live_view"
      import OtherHook from "./other_hook"

      let liveSocket = new LiveSocket("/live", Socket, {
        params: {},
        hooks: { OtherHook }
      })
      """

      project_with_app_js(app_js)
      |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.webauthn", [])
      |> assert_has_patch("assets/js/app.js", """
      - |  hooks: { OtherHook }
      + |  hooks: { OtherHook, WebAuthnRegistrationHook, WebAuthnAuthenticationHook, WebAuthnSupportHook }
      """)
    end

    test "spreads a hooks variable rather than replacing it" do
      app_js = """
      import { Socket } from "phoenix"
      import Hooks from "./hooks"

      let liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks })
      """

      project_with_app_js(app_js)
      |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.webauthn", [])
      |> assert_has_patch("assets/js/app.js", """
      - |let liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks })
      + |let liveSocket = new LiveSocket("/live", Socket, { hooks: { ...Hooks, WebAuthnRegistrationHook, WebAuthnAuthenticationHook, WebAuthnSupportHook } })
      """)
    end

    test "completes a half-wired file: only the missing hook is imported and registered" do
      app_js = """
      import { Socket } from "phoenix"
      import { WebAuthnRegistrationHook, WebAuthnAuthenticationHook } from "ash_authentication_phoenix/priv/static/webauthn_hooks.js"

      let liveSocket = new LiveSocket("/live", Socket, {
        hooks: { WebAuthnRegistrationHook, WebAuthnAuthenticationHook }
      })
      """

      project_with_app_js(app_js)
      |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.webauthn", [])
      |> assert_has_patch("assets/js/app.js", """
      - |import { WebAuthnRegistrationHook, WebAuthnAuthenticationHook } from "ash_authentication_phoenix/priv/static/webauthn_hooks.js"
      + |import { WebAuthnRegistrationHook, WebAuthnAuthenticationHook, WebAuthnSupportHook } from "ash_authentication_phoenix/priv/static/webauthn_hooks.js"
      """)
      |> assert_has_patch("assets/js/app.js", """
      - |  hooks: { WebAuthnRegistrationHook, WebAuthnAuthenticationHook }
      + |  hooks: { WebAuthnRegistrationHook, WebAuthnAuthenticationHook, WebAuthnSupportHook }
      """)
    end
  end

  describe "edge cases" do
    test "warns and leaves app.js untouched when missing" do
      test_project()
      |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.webauthn", [])
      |> assert_has_warning(&String.contains?(&1, "Could not find `assets/js/app.js`"))
    end

    test "warns and leaves app.js untouched when no LiveSocket is present" do
      project_with_app_js("console.log('hi')\n")
      |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.webauthn", [])
      |> assert_has_warning(
        &String.contains?(&1, "could not find a `liveSocket = new LiveSocket(...)` declaration")
      )
      |> assert_unchanged("assets/js/app.js")
    end

    test "warns and leaves app.js untouched when it doesn't parse" do
      project_with_app_js("let liveSocket = new LiveSocket(\n")
      |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.webauthn", [])
      |> assert_has_warning(&String.contains?(&1, "could not parse it"))
      |> assert_unchanged("assets/js/app.js")
    end

    test "leaves app.js untouched when hooks are already wired up manually" do
      manually_wired = """
      import "phoenix_html"
      import { Socket } from "phoenix"
      import { LiveSocket } from "phoenix_live_view"
      import { WebAuthnRegistrationHook, WebAuthnAuthenticationHook, WebAuthnSupportHook } from "ash_authentication_phoenix/priv/static/webauthn_hooks.js"

      let liveSocket = new LiveSocket("/live", Socket, {
        params: {},
        hooks: { WebAuthnRegistrationHook, WebAuthnAuthenticationHook, WebAuthnSupportHook }
      })
      """

      project_with_app_js(manually_wired)
      |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.webauthn", [])
      |> assert_unchanged("assets/js/app.js")
    end
  end

  # A project with ash_authentication installed, as the front door expects
  # to find it.
  defp installed_project do
    project_with_app_js()
    |> Igniter.Project.Deps.add_dep({:simple_sat, ">= 0.0.0"})
    |> Igniter.Project.Deps.add_dep({:ash_authentication, ">= 0.0.0"})
    |> Igniter.Project.Formatter.add_formatter_plugin(Spark.Formatter)
    |> Igniter.compose_task("ash_authentication.install", ["--yes"])
    |> apply_igniter!()
  end

  describe "via parent task" do
    test "ash_authentication_phoenix.add_strategy webauthn composes the JS hook installer" do
      installed_project()
      |> Igniter.compose_task("ash_authentication_phoenix.add_strategy", ["webauthn"])
      |> assert_has_patch("assets/js/app.js", """
      + |#{@import_line}
      """)
    end

    # `--no-config` is ash_authentication's as well: the strategy and the
    # `Secrets` clauses are written, the config files are not. It runs once
    # the pinned ash_authentication declares the flag.
    @tag skip:
           not Keyword.has_key?(
             Mix.Tasks.AshAuthentication.AddStrategy.Webauthn.info([], nil).schema,
             :config
           ) &&
             "needs an ash_authentication with --no-config (e9f2b77 on feat/webauthn-no-identity)"
    test "forwards --no-config to ash_authentication's webauthn task" do
      with_config =
        installed_project()
        |> Igniter.compose_task("ash_authentication_phoenix.add_strategy", ["webauthn"])

      assert diff(with_config, only: "config/dev.exs") =~ "webauthn_rp_id"

      without_config =
        installed_project()
        |> Igniter.compose_task("ash_authentication_phoenix.add_strategy", [
          "webauthn",
          "--no-config"
        ])

      assert diff(without_config, only: "lib/test/secrets.ex") =~ "webauthn_rp_id"
      assert_unchanged(without_config, "config/dev.exs")
      assert_unchanged(without_config, "config/test.exs")
      assert_unchanged(without_config, "config/runtime.exs")
    end

    # The front door declares no `--passkey-only` itself: Igniter merges the
    # schemas of the tasks it composes, so ash_authentication's flag passes
    # through it.
    test "forwards --passkey-only to ash_authentication's webauthn task" do
      diff =
        installed_project()
        |> Igniter.compose_task("ash_authentication_phoenix.add_strategy", [
          "webauthn",
          "--passkey-only"
        ])
        |> diff(only: "lib/test/accounts/user.ex")

      assert diff =~ "require_identity? false"
      refute diff =~ "identity_field :email"
      refute diff =~ "attribute :email"
    end

    test "forwards --passkey-only together with --mode 2fa" do
      result =
        installed_project()
        |> Igniter.compose_task("ash_authentication_phoenix.add_strategy", [
          "webauthn",
          "--passkey-only",
          "--mode",
          "2fa"
        ])

      diff = diff(result, only: "lib/test/accounts/user.ex")
      assert diff =~ "require_identity? false"
      assert diff =~ "registration_enabled? false"
      assert diff =~ "sign_in_enabled? false"

      # ash_authentication notes that the flag changes nothing in 2FA mode.
      assert_has_notice(result, &String.contains?(&1, "`--passkey-only` has no effect"))
    end

    # `--cross-device` is ash_authentication's too, and writes three options
    # on the strategy.
    test "forwards --cross-device to ash_authentication's webauthn task" do
      diff =
        installed_project()
        |> Igniter.compose_task("ash_authentication_phoenix.add_strategy", [
          "webauthn",
          "--cross-device"
        ])
        |> diff(only: "lib/test/accounts/user.ex")

      assert_cross_device(diff)
      refute diff =~ "require_identity? false"
    end

    test "forwards --cross-device together with --passkey-only" do
      diff =
        installed_project()
        |> Igniter.compose_task("ash_authentication_phoenix.add_strategy", [
          "webauthn",
          "--cross-device",
          "--passkey-only"
        ])
        |> diff(only: "lib/test/accounts/user.ex")

      assert_cross_device(diff)
      assert diff =~ "require_identity? false"
    end

    test "forwards --cross-device together with --mode 2fa" do
      diff =
        installed_project()
        |> Igniter.compose_task("ash_authentication_phoenix.add_strategy", [
          "webauthn",
          "--cross-device",
          "--mode",
          "2fa"
        ])
        |> diff(only: "lib/test/accounts/user.ex")

      assert_cross_device(diff)
      assert diff =~ "registration_enabled? false"
      assert diff =~ "sign_in_enabled? false"
    end
  end

  defp assert_cross_device(diff) do
    assert diff =~ "hints [:hybrid, :security_key]"
    assert diff =~ "timeout 180_000"
    assert diff =~ "allow_hint_override? true"
  end

  describe "--mode primary (default)" do
    test "doesn't add the 2FA-specific routes" do
      result =
        project_with_app_js()
        |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.webauthn", [])

      refute diff(result) =~ "webauthn_2fa_route"
      refute diff(result) =~ "webauthn_setup_route"
    end
  end
end
