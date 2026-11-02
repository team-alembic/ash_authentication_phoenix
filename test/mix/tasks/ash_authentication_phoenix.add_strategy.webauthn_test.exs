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

  describe "with a vanilla app.js" do
    test "imports the webauthn hooks module" do
      project_with_app_js()
      |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.webauthn", [])
      |> assert_has_patch("assets/js/app.js", """
      + |import { WebAuthnRegistrationHook, WebAuthnAuthenticationHook, WebAuthnSupportHook } from "ash_authentication_phoenix/priv/static/webauthn_hooks.js";
      """)
    end

    test "registers the hooks on the LiveSocket" do
      result =
        project_with_app_js()
        |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.webauthn", [])

      diff = diff(result, path: "assets/js/app.js")
      assert diff =~ "WebAuthnRegistrationHook"
      assert diff =~ "WebAuthnAuthenticationHook"
      assert diff =~ "WebAuthnSupportHook"
      assert diff =~ "hooks:"
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

      result =
        project_with_app_js(app_js)
        |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.webauthn", [])

      diff = diff(result, path: "assets/js/app.js")
      assert diff =~ "WebAuthnRegistrationHook"
      assert diff =~ "OtherHook"
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
        &String.contains?(&1, "Could not find a `liveSocket = new LiveSocket(...)` declaration")
      )
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
      + |import { WebAuthnRegistrationHook, WebAuthnAuthenticationHook, WebAuthnSupportHook } from "ash_authentication_phoenix/priv/static/webauthn_hooks.js";
      """)
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
        |> diff(path: "lib/test/accounts/user.ex")

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

      diff = diff(result, path: "lib/test/accounts/user.ex")
      assert diff =~ "require_identity? false"
      assert diff =~ "registration_enabled? false"
      assert diff =~ "sign_in_enabled? false"

      # ash_authentication notes that the flag changes nothing in 2FA mode.
      assert_has_notice(result, &String.contains?(&1, "`--passkey-only` has no effect"))
    end
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
