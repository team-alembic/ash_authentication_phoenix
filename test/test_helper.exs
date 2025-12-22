# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

Mimic.copy(Ash.Resource.Info)

ExUnit.start()

# Ensure the filter override module is loaded before tests
Code.require_file(Path.join(__DIR__, "filter_override.exs"))

AshAuthentication.Phoenix.Test.Endpoint.start_link()
