defmodule SCTPDebugDump do
  use Agent
  require Logger

  def start_link() do
    Agent.start_link(
      fn ->
        File.open!("debug_dump", [:write])
      end,
      name: __MODULE__
    )
  end

  def log(dump) do
    Agent.update(__MODULE__, fn handle ->
      Logger.info("DEBUG - Logging SCTP packet")
      IO.binwrite(handle, "NEWPACKET")
      IO.binwrite(handle, dump)
      handle
    end)
  end

  def child_spec() do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end
end
