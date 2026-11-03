# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

Mimic.copy(Ash.Resource.Info)
Mimic.copy(AshAuthentication.TokenResource.Info)

ExUnit.start()

Phoenix.PubSub.Supervisor.start_link(name: AshAuthentication.Phoenix.Test.PubSub)
AshAuthentication.Phoenix.Test.Endpoint.start_link()
