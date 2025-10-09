defmodule Ui.Voice.Store do
  @moduledoc false
  use GenServer

  @table_tokens :ui_voice_tokens
  @table_rate :ui_voice_rate

  def start_link(_), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  def init(:ok) do
    :ets.new(@table_tokens, [:named_table, :public, read_concurrency: true])
    :ets.new(@table_rate, [:named_table, :public, read_concurrency: true])
    {:ok, %{}}
  end

  def track_token(token) when is_binary(token) do
    expire = System.monotonic_time(:millisecond) + 60_000
    :ets.insert(@table_tokens, {token, %{issued_at: System.system_time(:second), expire: expire}})
    :ok
  end

  def allow_ip?(ip, max, window_ms) do
    now = System.monotonic_time(:millisecond)
    entries = case :ets.lookup(@table_rate, ip) do
      [{^ip, list}] -> list
      _ -> []
    end
    recent = Enum.filter(entries, fn ts -> now - ts < window_ms end)
    if length(recent) >= max do
      false
    else
      :ets.insert(@table_rate, {ip, [now | recent]})
      true
    end
  end
end

