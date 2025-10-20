<!--
SPDX-FileCopyrightText: 2022 Alembic Pty Ltd

SPDX-License-Identifier: MIT
-->

# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [v2.12.1](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.12.0...v2.12.1) (2025-10-20)




### Bug Fixes:

* require phoenix_live_view >= 1.1.0 to fix compile errors by James Harton

* dark-theme default text color (#677) by [@jaybarra](https://github.com/jaybarra) [(#677)](https://github.com/team-alembic/ash_authentication_phoenix/pull/677)

## [v2.12.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.11.0...v2.12.0) (2025-10-15)




### Features:

* Add support for remember me (#625) by [@rgraff](https://github.com/rgraff) [(#625)](https://github.com/team-alembic/ash_authentication_phoenix/pull/625)

### Bug Fixes:

* Support more than one authenticated resource when looking for user assigns (#675) by James Harton [(#675)](https://github.com/team-alembic/ash_authentication_phoenix/pull/675)

## [v2.11.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.10.5...v2.11.0) (2025-10-08)




### Features:

* added token validation on socket mount by Abdessabour Moutik [(#666)](https://github.com/team-alembic/ash_authentication_phoenix/pull/666)

* add icon_src override by Dawid Danieluk [(#660)](https://github.com/team-alembic/ash_authentication_phoenix/pull/660)

### Bug Fixes:

* banner rendering with empty text/images by James Harton

* update Apple component to use auth_path helper for Phoenix 1.7+ compatibility by Aake Gregertsen [(#663)](https://github.com/team-alembic/ash_authentication_phoenix/pull/663)

### Improvements:

* Deprecate Router.auth_routes_for/2..3 (#653) by James Harton [(#653)](https://github.com/team-alembic/ash_authentication_phoenix/pull/653)

* install with daisyUI overrides if using daisyUI (#650) by pikdum [(#650)](https://github.com/team-alembic/ash_authentication_phoenix/pull/650)

## [v2.10.5](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.10.4...v2.10.5) (2025-07-29)




### Improvements:

* debug form errors in templates by [@zachdaniel](https://github.com/zachdaniel)

## [v2.10.4](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.10.3...v2.10.4) (2025-07-22)




### Improvements:

* add daisyUI overrides (#642) by pikdum

## [v2.10.3](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.10.2...v2.10.3) (2025-07-09)




### Bug Fixes:

* add missing override for magic link input submit_label (#644) by skanderm

## [v2.10.2](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.10.1...v2.10.2) (2025-07-02)




### Improvements:

* Add override options to reset and sign in forms (#641) by [@jaeyson](https://github.com/jaeyson)

## [v2.10.1](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.10.0...v2.10.1) (2025-06-18)




### Bug Fixes:

* trigger action regardless of form validity by [@zachdaniel](https://github.com/zachdaniel)

* Google sign in (#635) by [@vasspilka](https://github.com/vasspilka)

### Improvements:

* don't add dangling ? at the end of URLs by [@zachdaniel](https://github.com/zachdaniel)

## [v2.10.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.9.0...v2.10.0) (2025-06-17)




### Bug Fixes:

* set subject name into forms for unique ids by [@zachdaniel](https://github.com/zachdaniel)

### Improvements:

* revoke stored sessions on log out (#634) by Zach Daniel

More information is available here: https://github.com/team-alembic/ash_authentication_phoenix/security/advisories/GHSA-f7gq-h8jv-h3cq


## [v2.9.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.8.0...v2.9.0) (2025-06-12)




### Features:

* google strategy uses official button svg (#626) by [@modellurgist](https://github.com/modellurgist)

### Bug Fixes:

* conditionally render button text, for :google strategy by [@modellurgist](https://github.com/modellurgist)

### Improvements:

* support `on_mount_prepend` in all route helpers by [@zachdaniel](https://github.com/zachdaniel)

* add on_mount_prepend option (#629) by aidalgol

## [v2.8.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.7.0...v2.8.0) (2025-06-10)




### Features:

* google strategy uses official button svg (#626) by [@modellurgist](https://github.com/modellurgist)

### Bug Fixes:

* conditionally render button text, for :google strategy by [@modellurgist](https://github.com/modellurgist)

### Improvements:

* add on_mount_prepend option (#629) by aidalgol

## [v2.7.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.6.3...v2.7.0) (2025-05-07)




### Features:

* Add override option for register form (#602)

### Bug Fixes:

* Confirm: Small tweaks to confirmation.

* only render real strategy components (#618)

* don't set current_tenant if no tenant is in session

* Password.SignInForm: Slugify the form param to match what AA expects. (#614)

### Improvements:

* MagicLink: Support `require_interaction?` in magic links. (#615)

* MagicLink: Support `require_interaction?` in magic links.

## [v2.6.3](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.6.2...v2.6.3) (2025-04-21)




### Bug Fixes:

* Fields with errors should keep their red border on focus, instead of going back to the default blue

* Replace `blue-pale` classes in styles with plain `blue`

* Use correct path to deps in post-install message for Tailwind 4

* Fixed grammar and improved clarity in default messages (#610)

### Improvements:

* support phoenix 1.8 verified routes behaviour

## [v2.6.2](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.6.1...v2.6.2) (2025-04-15)




### Bug Fixes:

* add parens around confirm_route/2-3

## [v2.6.1](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.6.0...v2.6.1) (2025-04-15)




### Bug Fixes:

* support token & confirm params in ConfirmLive

## [v2.6.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.5.4...v2.6.0) (2025-04-14)

### Improvements:

* mitigate medium-sev security issue for confirmation emails

For more information see the security advisory: https://github.com/team-alembic/ash_authentication/security/advisories/GHSA-3988-q8q7-p787


## [v2.5.4](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.5.3...v2.5.4) (2025-04-11)




### Bug Fixes:

* use proper path in installer for tailwind source

* make installer reasonably idempotent

## [v2.5.3](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.5.2...v2.5.3) (2025-04-09)




### Improvements:

* support tailwind 4 config

## [v2.5.2](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.5.1...v2.5.2) (2025-03-28)




### Improvements:

* `AshAuthentication.Phoenix.LiveSession.assign_new_resources/3` (#596)

* allow setting a subset of resources on sign in (#593)

## [v2.5.1](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.5.0...v2.5.1) (2025-03-20)




### Bug Fixes:

* use `tenant` and `context` options when building sign in form

## [v2.5.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.4.8...v2.5.0) (2025-03-18)




### Features:

* Display order for strategies in sign in page (#591)

## [v2.4.8](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.4.7...v2.4.8) (2025-02-25)




### Bug Fixes:

* ensure all forms set current_tenant

* properly stringify lists of atoms in gettext

### Improvements:

* add `LiveSession.opts/1` for compatibility

## [v2.4.7](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.4.6...v2.4.7) (2025-02-11)




### Bug Fixes:

* Use correct task name for route helper alias

* Add strategy name to reset form IDs. (#577)

### Improvements:

* call gettext fn on errors (#573)

* call gettext fn on errors

## [v2.4.6](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.4.5...v2.4.6) (2025-01-27)




### Improvements:

* add `ash_authentication_phoenix.routes` to `phx.routes`

## [v2.4.5](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.4.4...v2.4.5) (2025-01-27)




### Bug Fixes:

* duplicate border color CSS in defaults

* Missing comma in igniter-generated Phoenix overrides (#556)

### Improvements:

* automatically add sources to assets/tailwind.config.js

* gettext_backend convenience wrapper (#563)

* i18n with a custom gettext function (#561)

* factor out shared input field CSS

* optional gettext, docs

* Allow changing text of submit buttons (#562)

* allow configurable AshAuthentication.Phoenix.StrategyRouter

* set `yes_to_deps` when fetching dependencies

## [v2.4.4](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.4.3...v2.4.4) (2024-12-26)




### Bug Fixes:

* fix installer for cases where liveview is not included

## [v2.4.3](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.4.2...v2.4.3) (2024-12-26)




### Improvements:

* match on any source of `CannotConfirmUnconfirmedUser`

* generate auth code for graphql & add `set_user` plug for

## [v2.4.2](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.4.1...v2.4.2) (2024-12-20)




### Bug Fixes:

* Set the expected message in failure function generators. (#550)

### Improvements:

* make igniter optional

* update message with helpful instructions

## [v2.4.1](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.4.0...v2.4.1) (2024-12-12)




### Improvements:

* provide better error message on hijack protection

* Pass opts of plugs to retrieve helpers (#546)

## [v2.4.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.3.0...v2.4.0) (2024-12-05)




### Improvements:

* update to latest phoenix_live_view 1.0

## [v2.3.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.2.1...v2.3.0) (2024-11-26)

### Features:

- Add override for identity input placeholder (#538)

- Add action-specific flash messages to the generated AuthController (#532)

### Bug Fixes:

- handle tenant-specific query in Password Reset Form handle_event/3 (#537)

- Apply overrides to password reset update form (#529)

## [v2.2.1](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.2.0...v2.2.1) (2024-11-13)

### Bug Fixes:

- Components.Password.ResetForm: Handle the fact that we now ask users to use a generic action. (#531)

## [v2.2.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.1.11...v2.2.0) (2024-11-05)

### Features:

- Slack: Add icon for Slack strategy. (#524)

## [v2.1.11](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.1.10...v2.1.11) (2024-10-31)

### Improvements:

- validate each form on submit to avoid warning

## [v2.1.10](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.1.9...v2.1.10) (2024-10-24)

### Bug Fixes:

- ensure current_tenant is set

- pass tenant as option instead of before_submit

## [v2.1.9](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.1.8...v2.1.9) (2024-10-15)

### Bug Fixes:

- ensure browser pipeline is added to installer

## [v2.1.8](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.1.7...v2.1.8) (2024-10-14)

### Bug Fixes:

- properly parse flag options

## [v2.1.7](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.1.6...v2.1.7) (2024-10-14)

### Improvements:

- set a `group` on install task

## [v2.1.6](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.1.5...v2.1.6) (2024-10-14)

### Bug Fixes:

- don't pass api option to forms

## [v2.1.5](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.1.4...v2.1.5) (2024-10-11)

### Improvements:

- recommend a single ash_authentication_live_session in installer

- log a warning on failure to create a magic link

## [v2.1.4](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.1.3...v2.1.4) (2024-10-08)

### Improvements:

- generate overrides module in installer

## [v2.1.3](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.1.2...v2.1.3) (2024-10-06)

### Improvements:

- `mix igniter.install ash_authentication_phoenix` (#504)

## [v2.1.2](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.1.1...v2.1.2) (2024-09-23)

### Bug Fixes:

- apply `auth_routes_prefix` logic to `reset_route` as well

## [v2.1.1](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.1.0...v2.1.1) (2024-09-03)

### Bug Fixes:

- ensure that params are sent when using route helpers

## [v2.1.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.0.2...v2.1.0) (2024-09-01)

### Features:

- Dynamic Router + compile time dependency fixes (#487)

### Bug Fixes:

- check strategy module instead of name

- ensure path params are processed on strategy router

- Re-link form labels and form inputs on Password strategy forms (#494)

- Restore linkage between form inputs and form fields on Password strategy form

- Use separate override labels for Password and Password Confirmation fields

- only scope reset/register paths if they are set

- Ensure session respects router scope when using sign_in_route helper (#490)

### Improvements:

- add button for the Apple strategy (#482)

- add apple component

- pass context down to all actions

- create a new dynamic router, and avoid other compile time dependencies

## [v2.0.2](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.0.1...v2.0.2) (2024-08-05)

### Bug Fixes:

- use any overridden value, including `nil` or `false` (#476)

- set tenant in sign_in and reset_route (#478)

### Improvements:

- Added overrides for identity (email) and password fields. (#477)

## [v2.0.1](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.0.0...v2.0.1) (2024-07-10)

### Improvements:

- fix deprecation warnings about live_flash/2.

## [v2.0.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.0.0-rc.3...v2.0.0) (2024-05-10)

### Bug Fixes:

- set tenant on form creation

## [v2.0.0-rc.3](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.0.0-rc.2...v2.0.0-rc.3) (2024-05-10)

### Bug Fixes:

- set tenant on form creation

## [v2.0.0-rc.2](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.0.0-rc.1...v2.0.0-rc.2) (2024-04-13)

### Bug Fixes:

- show password strategy message if `field` is `nil`

## [v2.0.0-rc.1](https://github.com/team-alembic/ash_authentication_phoenix/compare/v2.0.0-rc.0...v2.0.0-rc.1) (2024-04-02)

### Breaking Changes:

- Update to support Ash 3.0, et al.

### Bug Fixes:

- loosen rc requirements

- Fix typos in override class names

- honour the error field in AuthenticationFailed errors in forms. (#368)

- Ensure that `sign_in_route` and `reset_route` correctly initialise session. (#369)

## [v2.0.0-rc.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.9.4...v2.0.0-rc.0) (2024-04-01)

### Breaking Changes:

- Update to support Ash 3.0, et al.

## [v1.9.4](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.9.3...v1.9.4) (2024-03-06)

### Bug Fixes:

- Fix typos in override class names

## [v1.9.3](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.9.2...v1.9.3) (2024-03-05)

### Bug Fixes:

- Fix typos in override class names

## [v1.9.2](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.9.1...v1.9.2) (2024-02-02)

### Bug Fixes:

- Ensure that `sign_in_route` and `reset_route` correctly initialise session. (#369)

## [v1.9.1](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.9.0...v1.9.1) (2024-01-21)

## [v1.9.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.8.7...v1.9.0) (2023-11-13)

### Features:

- Add rendering of flash messages from live components

## [v1.8.7](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.8.6...v1.8.7) (2023-10-26)

### Bug Fixes:

- Pass tenant to generated Live View forms (#310)

- pull assign out of other flow

- sets a nil value in assigns for :current_tenant in subcomponents if not already set

## [v1.8.6](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.8.5...v1.8.6) (2023-10-25)

### Bug Fixes:

- incorrect introspection target in password strategy. (#317)

## [v1.8.5](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.8.4...v1.8.5) (2023-10-06)

### Bug Fixes:

- properly navigate back to root component when routes are not set (#296)

## [v1.8.4](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.8.3...v1.8.4) (2023-10-01)

### Improvements:

- optional support for routing to register & reset links (#281)

## [v1.8.3](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.8.2...v1.8.3) (2023-09-23)

### Bug Fixes:

- resettable is no longer a list

## [v1.8.2](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.8.1...v1.8.2) (2023-09-22)

### Bug Fixes:

- handle change from ash_authentication where resettable is no lonâ¦ (#279)

## [v1.8.1](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.8.0...v1.8.1) (2023-09-18)

### Improvements:

- submit form in-line when sign_in_tokens_enabled (#274)

- submit form in-line when sign_in_tokens_enabled

## [v1.8.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.7.3...v1.8.0) (2023-09-14)

### Features:

- change `ash_authentication_live_session` to use `assign_new` (#270)

## [v1.7.3](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.7.2...v1.7.3) (2023-08-09)

### Bug Fixes:

- Overrides in reset route (#250)

## [v1.7.2](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.7.1...v1.7.2) (2023-04-16)

### Improvements:

- Add OIDC and generic "lock" icons.

## [v1.7.1](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.7.0...v1.7.1) (2023-04-12)

### Bug Fixes:

- backwards compat with sign_in_tokens_enabled?

## [v1.7.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.6.6...v1.7.0) (2023-04-06)

### Features:

- support new sign in tokens feature on password strategy (#176)

## [v1.6.6](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.6.5...v1.6.6) (2023-03-31)

### Bug Fixes:

- better behavior when password registration disabled

- only show register page if register is enabled

- resolve issues w/ assigning socket & test helper flash

## [v1.6.5](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.6.4...v1.6.5) (2023-03-26)

### Bug Fixes:

- better behavior when password registration disabled

- only show register page if register is enabled

- resolve issues w/ assigning socket & test helper flash

## [v1.6.4](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.6.3...v1.6.4) (2023-03-14)

### Bug Fixes:

- always set `tenant` session

## [v1.6.3](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.6.2...v1.6.3) (2023-03-13)

### Bug Fixes:

- always set `tenant` session

## [v1.6.2](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.6.1...v1.6.2) (2023-03-06)

### Bug Fixes:

- add `phoenix_view` to dependencies. (#153)

## [v1.6.1](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.6.0...v1.6.1) (2023-03-01)

### Improvements:

- allow folks to disable togglers by setting their text to `nil`.

## [v1.6.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.5.1...v1.6.0) (2023-02-27)

### Features:

- Allow on_mount for reset_routes for browser testing (#139)

## [v1.5.1](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.5.0...v1.5.1) (2023-02-24)

### Improvements:

- configurable otp app (#135)

## [v1.5.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.4.8...v1.5.0) (2023-02-12)

### Features:

- MagicLink: Add the UI for requesting a magic link. (#121)

## [v1.4.8](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.4.7...v1.4.8) (2023-02-07)

### Improvements:

- Autofocus identity field in password component (#105)

## [v1.4.7](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.4.6...v1.4.7) (2023-01-30)

### Improvements:

- ensure horizontal rules get a unique id (#99)

## [v1.4.6](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.4.5...v1.4.6) (2023-01-29)

### Improvements:

- improve default theme on dark mode. (#87)

- Add override introspection and tidy up docs.

## [v1.4.5](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.4.4...v1.4.5) (2023-01-26)

### Improvements:

- remove readme contents, add tutorial (#81)

## [v1.4.4](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.4.3...v1.4.4) (2023-01-19)

### Improvements:

- make `ash_authentication_live_session` support opts (#74)

## [v1.4.3](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.4.2...v1.4.3) (2023-01-18)

### Improvements:

- remove spark doc index (#63)

## [v1.4.2](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.4.1...v1.4.2) (2023-01-13)

### Bug Fixes:

- set ash_authentication? context on forms (#56)

## [v1.4.1](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.4.0...v1.4.1) (2023-01-12)

### Improvements:

- Add Github icon. (#55)

## [v1.4.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.3.1...v1.4.0) (2023-01-12)

### Features:

- LiveSession: Add `ash_authentication_live_session` macro to router. (#54)

## [v1.3.1](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.3.0...v1.3.1) (2023-01-10)

### Bug Fixes:

- deps: Loosen version constraints on deps.

## [v1.3.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.2.0...v1.3.0) (2022-12-16)

### Features:

- Add Auth0 icon.

## [v1.2.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.1.0...v1.2.0) (2022-12-15)

### Features:

- PasswordReset: Add a generic password reset form (#37)

- PasswordReset: Add a generic password reset form

### Improvements:

- Input.submit: trim trailing "with password" from submit buttons.

## [v1.1.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.0.1...v1.1.0) (2022-12-15)

### Features:

- Overrides: Move overrides from application environment to the `sign_in_route` macro. (#36)

## [v1.0.1](https://github.com/team-alembic/ash_authentication_phoenix/compare/v1.0.0...v1.0.1) (2022-12-14)

### Improvements:

- Components.Banner: Allow image, text and hrefs to be disabled with `nil`. (#35)

## [v0.5.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v0.4.0...v0.5.0) (2022-11-14)

### Features:

- OAuth2: Add OAuth2 link component. (#12)

## [v0.4.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v0.3.0...v0.4.0) (2022-11-10)

### Features:

- Confirmation: Add confirmation support.

## [v0.3.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v0.2.0...v0.3.0) (2022-11-03)

### Features:

- PasswordReset: Add password reset support to the UI. (#10)

## [v0.2.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v0.1.0...v0.2.0) (2022-10-28)

### Features:

- UI refresh. (#3)

## [v0.1.0](https://github.com/team-alembic/ash_authentication_phoenix/compare/v0.1.0...v0.1.0) (2022-10-25)

### Features:

- Add support for PasswordAuthentication.
