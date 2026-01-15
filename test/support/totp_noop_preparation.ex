# SPDX-FileCopyrightText: 2024 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule Example.TotpNoopPreparation do
  @moduledoc """
  A noop brute force preparation for testing TOTP.

  Supports both read actions (Query) and generic actions (ActionInput).
  """
  use Ash.Resource.Preparation

  @doc """
  Declares support for all subject types used by TOTP actions.
  """
  @impl true
  def supports(_opts), do: [Ash.Query, Ash.ActionInput, Ash.Changeset]

  @doc """
  Returns the query or action input unchanged (noop).
  """
  @impl true
  def prepare(query_or_input, _opts, _context), do: query_or_input
end
