# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

Mimic.copy(Ash.Resource.Info)

# Hammer backend for the OAuth2 server rate-limit fixture
# (`Oauth2ServerTest.RateLimitedOAuthClient` in test/support).
{:ok, _} = Oauth2ServerTest.Hammer.start_link(clean_period: :timer.minutes(1))

ExUnit.start()

AshAuthentication.Phoenix.Test.Endpoint.start_link()
